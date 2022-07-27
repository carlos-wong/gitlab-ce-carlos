# frozen_string_literal: true

module Users
  module CalloutsHelper
    GKE_CLUSTER_INTEGRATION = 'gke_cluster_integration'
    GCP_SIGNUP_OFFER = 'gcp_signup_offer'
    SUGGEST_POPOVER_DISMISSED = 'suggest_popover_dismissed'
    TABS_POSITION_HIGHLIGHT = 'tabs_position_highlight'
    FEATURE_FLAGS_NEW_VERSION = 'feature_flags_new_version'
    REGISTRATION_ENABLED_CALLOUT = 'registration_enabled_callout'
    UNFINISHED_TAG_CLEANUP_CALLOUT = 'unfinished_tag_cleanup_callout'
    SECURITY_NEWSLETTER_CALLOUT = 'security_newsletter_callout'
    REGISTRATION_ENABLED_CALLOUT_ALLOWED_CONTROLLER_PATHS = [/^root/, /^dashboard\S*/, /^admin\S*/].freeze
    WEB_HOOK_DISABLED = 'web_hook_disabled'

    def show_gke_cluster_integration_callout?(project)
      active_nav_link?(controller: sidebar_operations_paths) &&
        can?(current_user, :create_cluster, project) &&
        !user_dismissed?(GKE_CLUSTER_INTEGRATION)
    end

    def show_gcp_signup_offer?
      !user_dismissed?(GCP_SIGNUP_OFFER)
    end

    def render_flash_user_callout(flash_type, message, feature_name)
      render 'shared/flash_user_callout', flash_type: flash_type, message: message, feature_name: feature_name
    end

    def render_dashboard_ultimate_trial(user)
    end

    def render_two_factor_auth_recovery_settings_check
    end

    def show_suggest_popover?
      !user_dismissed?(SUGGEST_POPOVER_DISMISSED)
    end

    def show_feature_flags_new_version?
      !user_dismissed?(FEATURE_FLAGS_NEW_VERSION)
    end

    def show_unfinished_tag_cleanup_callout?
      !user_dismissed?(UNFINISHED_TAG_CLEANUP_CALLOUT)
    end

    def show_registration_enabled_user_callout?
      !Gitlab.com? &&
        current_user&.admin? &&
        signup_enabled? &&
        !user_dismissed?(REGISTRATION_ENABLED_CALLOUT) &&
        REGISTRATION_ENABLED_CALLOUT_ALLOWED_CONTROLLER_PATHS.any? { |path| controller.controller_path.match?(path) }
    end

    def dismiss_two_factor_auth_recovery_settings_check
    end

    def show_security_newsletter_user_callout?
      current_user&.admin? &&
        !user_dismissed?(SECURITY_NEWSLETTER_CALLOUT)
    end

    def web_hook_disabled_dismissed?(project)
      return false unless project

      last_failure = Gitlab::Redis::SharedState.with do |redis|
        key = "web_hooks:last_failure:project-#{project.id}"
        redis.get(key)
      end

      last_failure = DateTime.parse(last_failure) if last_failure

      user_dismissed?(WEB_HOOK_DISABLED, last_failure, namespace: project.namespace)
    end

    private

    def user_dismissed?(feature_name, ignore_dismissal_earlier_than = nil, namespace: nil)
      return false unless current_user

      query = { feature_name: feature_name, ignore_dismissal_earlier_than: ignore_dismissal_earlier_than }

      if namespace
        current_user.dismissed_callout_for_namespace?(namespace: namespace, **query)
      else
        current_user.dismissed_callout?(**query)
      end
    end
  end
end

Users::CalloutsHelper.prepend_mod
