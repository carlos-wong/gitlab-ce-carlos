# frozen_string_literal: true

class Import::GiteaController < Import::GithubController
  extend ::Gitlab::Utils::Override

  before_action :verify_blocked_uri, only: :status

  def new
    if session[access_token_key].present? && provider_url.present?
      redirect_to status_import_url
    end
  end

  def personal_access_token
    session[host_key] = params[host_key]
    super
  end

  # We need to re-expose controller's internal method 'status' as action.
  # rubocop:disable Lint/UselessMethodDefinition
  def status
    super
  end
  # rubocop:enable Lint/UselessMethodDefinition

  protected

  override :provider_name
  def provider_name
    :gitea
  end

  private

  def host_key
    :"#{provider_name}_host_url"
  end

  override :provider_url
  def provider_url
    session[host_key]
  end

  # Gitea is not yet an OAuth provider
  # See https://github.com/go-gitea/gitea/issues/27
  override :logged_in_with_provider?
  def logged_in_with_provider?
    false
  end

  override :provider_auth
  def provider_auth
    if session[access_token_key].blank? || provider_url.blank?
      redirect_to new_import_gitea_url,
        alert: _('You need to specify both an Access Token and a Host URL.')
    end
  end

  override :client_repos
  def client_repos
    @client_repos ||= filtered(client.repos)
  end

  override :client
  def client
    @client ||= Gitlab::LegacyGithubImport::Client.new(session[access_token_key], **client_options)
  end

  override :client_options
  def client_options
    verified_url, provider_hostname = verify_blocked_uri

    { host: verified_url.scheme == 'https' ? provider_url : verified_url.to_s, api_version: 'v1', hostname: provider_hostname }
  end

  def verify_blocked_uri
    @verified_url_and_hostname ||= Gitlab::UrlBlocker.validate!(
      provider_url,
      allow_localhost: allow_local_requests?,
      allow_local_network: allow_local_requests?,
      schemes: %w(http https)
    )
  rescue Gitlab::UrlBlocker::BlockedUrlError => e
    session[access_token_key] = nil

    redirect_to new_import_url, alert: _('Specified URL cannot be used: "%{reason}"') % { reason: e.message }
  end

  def allow_local_requests?
    Gitlab::CurrentSettings.allow_local_requests_from_web_hooks_and_services?
  end
end
