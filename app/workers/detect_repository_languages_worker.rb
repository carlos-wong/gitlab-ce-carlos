# frozen_string_literal: true

class DetectRepositoryLanguagesWorker
  include ApplicationWorker
  include ExceptionBacktrace
  include ExclusiveLeaseGuard

  sidekiq_options retry: 1

  LEASE_TIMEOUT = 300

  attr_reader :project

  # rubocop: disable CodeReuse/ActiveRecord
  def perform(project_id, user_id = nil)
    @project = Project.find_by(id: project_id)
    return unless project

    try_obtain_lease do
      ::Projects::DetectRepositoryLanguagesService.new(project).execute
    end
  end
  # rubocop: enable CodeReuse/ActiveRecord

  private

  def lease_timeout
    LEASE_TIMEOUT
  end

  def lease_key
    "gitlab:detect_repository_languages:#{project.id}"
  end
end
