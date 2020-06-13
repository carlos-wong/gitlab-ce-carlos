# frozen_string_literal: true

module HashedStorage
  class ProjectRollbackWorker < BaseWorker # rubocop:disable Scalability/IdempotentWorker
    include ApplicationWorker

    queue_namespace :hashed_storage

    attr_reader :project_id

    # rubocop: disable CodeReuse/ActiveRecord
    def perform(project_id, old_disk_path = nil)
      @project_id = project_id # we need to set this in order to create the lease_key

      try_obtain_lease do
        project = Project.without_deleted.find_by(id: project_id)
        break unless project

        old_disk_path ||= project.disk_path

        ::Projects::HashedStorage::RollbackService.new(project, old_disk_path, logger: logger).execute
      end
    end
    # rubocop: enable CodeReuse/ActiveRecord
  end
end
