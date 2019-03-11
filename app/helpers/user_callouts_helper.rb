# frozen_string_literal: true

module UserCalloutsHelper
  GKE_CLUSTER_INTEGRATION = 'gke_cluster_integration'.freeze
  GCP_SIGNUP_OFFER = 'gcp_signup_offer'.freeze

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

  private

  def user_dismissed?(feature_name)
    current_user&.callouts&.find_by(feature_name: UserCallout.feature_names[feature_name])
  end
end
