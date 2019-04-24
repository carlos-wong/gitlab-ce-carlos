# frozen_string_literal: true

class ClusterConfigureWorker
  include ApplicationWorker
  include ClusterQueue

  def perform(cluster_id)
    Clusters::Cluster.find_by_id(cluster_id).try do |cluster|
      if cluster.project_type? || Feature.disabled?(:ci_preparing_state, default_enabled: true)
        Clusters::RefreshService.create_or_update_namespaces_for_cluster(cluster)
      end
    end
  end
end
