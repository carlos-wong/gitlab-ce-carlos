# frozen_string_literal: true

class JiraConnect::SubscriptionsController < JiraConnect::ApplicationController
  layout 'jira_connect'

  content_security_policy do |p|
    next if p.directives.blank?

    # rubocop: disable Lint/PercentStringArray
    script_src_values = Array.wrap(p.directives['script-src']) | %w('self' https://connect-cdn.atl-paas.net)
    style_src_values = Array.wrap(p.directives['style-src']) | %w('self' 'unsafe-inline')
    # rubocop: enable Lint/PercentStringArray

    # *.jira.com is needed for some legacy Jira Cloud instances, new ones will use *.atlassian.net
    # https://support.atlassian.com/organization-administration/docs/ip-addresses-and-domains-for-atlassian-cloud-products/
    p.frame_ancestors :self, 'https://*.atlassian.net', 'https://*.jira.com'
    p.script_src(*script_src_values)
    p.style_src(*style_src_values)
  end

  before_action do
    push_frontend_feature_flag(:jira_connect_oauth, @user)
    push_frontend_feature_flag(:jira_connect_oauth_self_managed, @user)
  end

  before_action :allow_rendering_in_iframe, only: :index
  before_action :verify_qsh_claim!, only: :index
  before_action :allow_self_managed_content_security_policy, only: :index
  before_action :authenticate_user!, only: :create

  def index
    @subscriptions = current_jira_installation.subscriptions.preload_namespace_route

    respond_to do |format|
      format.html
      format.json do
        render json: JiraConnect::AppDataSerializer.new(@subscriptions, !!current_user).as_json
      end
    end
  end

  def create
    result = create_service.execute

    if result[:status] == :success
      render json: { success: true }
    else
      render json: { error: result[:message] }, status: result[:http_status]
    end
  end

  def destroy
    subscription = current_jira_installation.subscriptions.find(params[:id])

    if !jira_user&.site_admin?
      render json: { error: 'forbidden' }, status: :forbidden
    elsif subscription.destroy
      render json: { success: true }
    else
      render json: { error: subscription.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  private

  def allow_self_managed_content_security_policy
    return unless current_jira_installation.instance_url?

    request.content_security_policy.directives['connect-src'] ||= []
    request.content_security_policy.directives['connect-src'] << Gitlab::Utils.append_path(current_jira_installation.instance_url, '/-/jira_connect/oauth_application_ids')
  end

  def create_service
    JiraConnectSubscriptions::CreateService.new(current_jira_installation, current_user, namespace_path: params['namespace_path'], jira_user: jira_user)
  end

  def allow_rendering_in_iframe
    response.headers.delete('X-Frame-Options')
  end
end
