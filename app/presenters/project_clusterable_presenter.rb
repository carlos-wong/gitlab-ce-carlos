# frozen_string_literal: true

class ProjectClusterablePresenter < ClusterablePresenter
  extend ::Gitlab::Utils::Override
  include ActionView::Helpers::UrlHelper

  override :cluster_status_cluster_path
  def cluster_status_cluster_path(cluster, params = {})
    cluster_status_project_cluster_path(clusterable, cluster, params)
  end

  override :install_applications_cluster_path
  def install_applications_cluster_path(cluster, application)
    install_applications_project_cluster_path(clusterable, cluster, application)
  end

  override :update_applications_cluster_path
  def update_applications_cluster_path(cluster, application)
    update_applications_project_cluster_path(clusterable, cluster, application)
  end

  override :cluster_path
  def cluster_path(cluster, params = {})
    project_cluster_path(clusterable, cluster, params)
  end

  override :sidebar_text
  def sidebar_text
    s_('ClusterIntegration|With a Kubernetes cluster associated to this project, you can use review apps, deploy your applications, run your pipelines, and much more in an easy way.')
  end

  override :learn_more_link
  def learn_more_link
    link_to(s_('ClusterIntegration|Learn more about Kubernetes'), help_page_path('user/project/clusters/index'), target: '_blank', rel: 'noopener noreferrer')
  end
end

ProjectClusterablePresenter.prepend_if_ee('EE::ProjectClusterablePresenter')
