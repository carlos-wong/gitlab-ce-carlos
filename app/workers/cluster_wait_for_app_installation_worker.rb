# frozen_string_literal: true

class ClusterWaitForAppInstallationWorker
  include ApplicationWorker
  include ClusterQueue
  include ClusterApplications

  INTERVAL = 10.seconds
  TIMEOUT = 20.minutes

  worker_has_external_dependencies!
  worker_resource_boundary :cpu

  def perform(app_name, app_id)
    find_application(app_name, app_id) do |app|
      Clusters::Applications::CheckInstallationProgressService.new(app).execute
    end
  end
end
