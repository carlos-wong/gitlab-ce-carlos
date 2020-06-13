# frozen_string_literal: true

module UserCalloutsHelper
  GKE_CLUSTER_INTEGRATION = 'gke_cluster_integration'
  GCP_SIGNUP_OFFER = 'gcp_signup_offer'
  SUGGEST_POPOVER_DISMISSED = 'suggest_popover_dismissed'
  TABS_POSITION_HIGHLIGHT = 'tabs_position_highlight'
  WEBHOOKS_MOVED = 'webhooks_moved'

  def show_gke_cluster_integration_callout?(project)
    can?(current_user, :create_cluster, project) &&
      !user_dismissed?(GKE_CLUSTER_INTEGRATION)
  end

  def show_gcp_signup_offer?
    !user_dismissed?(GCP_SIGNUP_OFFER)
  end

  def render_flash_user_callout(flash_type, message, feature_name)
    render 'shared/flash_user_callout', flash_type: flash_type, message: message, feature_name: feature_name
  end

  def render_dashboard_gold_trial(user)
  end

  def render_account_recovery_regular_check
  end

  def show_suggest_popover?
    !user_dismissed?(SUGGEST_POPOVER_DISMISSED)
  end

  def show_tabs_feature_highlight?
    current_user && !user_dismissed?(TABS_POSITION_HIGHLIGHT) && !Rails.env.test?
  end

  def show_webhooks_moved_alert?
    !user_dismissed?(WEBHOOKS_MOVED)
  end

  private

  def user_dismissed?(feature_name, ignore_dismissal_earlier_than = nil)
    return false unless current_user

    current_user.dismissed_callout?(feature_name: feature_name, ignore_dismissal_earlier_than: ignore_dismissal_earlier_than)
  end
end

UserCalloutsHelper.prepend_if_ee('EE::UserCalloutsHelper')
