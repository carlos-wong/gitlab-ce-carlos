# frozen_string_literal: true

module Users
  class TermsController < ApplicationController
    include InternalRedirect

    skip_before_action :authenticate_user!, only: [:index]
    skip_before_action :enforce_terms!
    skip_before_action :check_password_expiration
    skip_before_action :check_two_factor_requirement
    skip_before_action :require_email

    before_action :terms

    layout 'terms'

    def index
      @redirect = redirect_path

      if current_user && @term.accepted_by_user?(current_user)
        flash.now[:notice] = "You have already accepted the Terms of Service as #{current_user.to_reference}"
      end
    end

    def accept
      agreement = Users::RespondToTermsService.new(current_user, viewed_term)
                    .execute(accepted: true)

      if agreement.persisted?
        redirect_to redirect_path
      else
        flash[:alert] = agreement.errors.full_messages.join(', ')
        redirect_to terms_path, redirect: redirect_path
      end
    end

    def decline
      agreement = Users::RespondToTermsService.new(current_user, viewed_term)
                    .execute(accepted: false)

      if agreement.persisted?
        sign_out(current_user)
        redirect_to root_path
      else
        flash[:alert] = agreement.errors.full_messages.join(', ')
        redirect_to terms_path, redirect: redirect_path
      end
    end

    private

    def viewed_term
      @viewed_term ||= ApplicationSetting::Term.find(params[:id])
    end

    def terms
      unless @term = Gitlab::CurrentSettings.current_application_settings.latest_terms
        redirect_to redirect_path
      end
    end

    def redirect_path
      redirect_to_path = safe_redirect_path(params[:redirect]) || safe_redirect_path_for_url(request.referer)

      if redirect_to_path &&
          excluded_redirect_paths.none? { |excluded| redirect_to_path.include?(excluded) }
        redirect_to_path
      else
        root_path
      end
    end

    def excluded_redirect_paths
      [terms_path, new_user_session_path]
    end
  end
end
