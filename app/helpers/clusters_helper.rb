# frozen_string_literal: true

module ClustersHelper
  # EE overrides this
  def has_multiple_clusters?
    false
  end

  def create_new_cluster_label(provider: nil)
    case provider
    when 'aws'
      s_('ClusterIntegration|Create new cluster on EKS')
    when 'gcp'
      s_('ClusterIntegration|Create new cluster on GKE')
    else
      s_('ClusterIntegration|Create new cluster')
    end
  end

  def render_gcp_signup_offer
    return if Gitlab::CurrentSettings.current_application_settings.hide_third_party_offers?
    return unless show_gcp_signup_offer?

    content_tag :section, class: 'no-animate expanded' do
      render 'clusters/clusters/gcp_signup_offer_banner'
    end
  end

  def render_cluster_info_tab_content(tab, expanded)
    case tab
    when 'environments'
      render_if_exists 'clusters/clusters/environments'
    when 'health'
      render_if_exists 'clusters/clusters/health'
    when 'apps'
      render 'applications'
    when 'settings'
      render 'advanced_settings_container'
    else
      render('details', expanded: expanded)
    end
  end

  def has_rbac_enabled?(cluster)
    return cluster.platform_kubernetes_rbac? if cluster.platform_kubernetes

    cluster.provider.has_rbac_enabled?
  end

  def project_cluster?(cluster)
    cluster.cluster_type.in?('project_type')
  end

  def cluster_created?(cluster)
    !cluster.status_name.in?(%i/scheduled creating/)
  end

  def can_admin_cluster?(user, cluster)
    can?(user, :admin_cluster, cluster)
  end
end

ClustersHelper.prepend_if_ee('EE::ClustersHelper')
