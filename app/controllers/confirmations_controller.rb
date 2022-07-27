# frozen_string_literal: true

class ConfirmationsController < Devise::ConfirmationsController
  include AcceptsPendingInvitations
  include GitlabRecaptcha
  include OneTrustCSP
  include GoogleAnalyticsCSP

  prepend_before_action :check_recaptcha, only: :create
  before_action :load_recaptcha, only: :new

  feature_category :authentication_and_authorization

  def almost_there
    flash[:notice] = nil
    render layout: "devise_empty"
  end

  protected

  def after_resending_confirmation_instructions_path_for(resource)
    return users_almost_there_path unless Feature.enabled?(:soft_email_confirmation)

    stored_location_for(resource) || dashboard_projects_path
  end

  def after_confirmation_path_for(resource_name, resource)
    accept_pending_invitations

    # incoming resource can either be a :user or an :email
    if signed_in?(:user)
      after_sign_in(resource)
    else
      Gitlab::AppLogger.info("Email Confirmed: username=#{resource.username} email=#{resource.email} ip=#{request.remote_ip}")
      flash[:notice] = flash[:notice] + _(" Please sign in.")
      new_session_path(:user, anchor: 'login-pane', invite_email: resource.email)
    end
  end

  def check_recaptcha
    return unless resource_params[:email].present?

    super
  end

  def after_sign_in(resource)
    after_sign_in_path_for(resource)
  end

  def context_user
    resource
  end
end

ConfirmationsController.prepend_mod_with('ConfirmationsController')
