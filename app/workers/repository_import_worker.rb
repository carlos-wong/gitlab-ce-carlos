# frozen_string_literal: true

class RepositoryImportWorker
  include ApplicationWorker
  include ExceptionBacktrace
  include ProjectStartImport
  include ProjectImportOptions

  def perform(project_id)
    @project = Project.find(project_id)

    return unless start_import

    Gitlab::Metrics.add_event(:import_repository)

    service = Projects::ImportService.new(project, project.creator)
    result = service.execute

    # Some importers may perform their work asynchronously. In this case it's up
    # to those importers to mark the import process as complete.
    return if service.async?

    if result[:status] == :error
      fail_import(result[:message]) if template_import?

      raise result[:message]
    end

    project.after_import
  end

  private

  attr_reader :project

  def start_import
    return true if start(project.import_state)

    Rails.logger.info("Project #{project.full_path} was in inconsistent state (#{project.import_status}) while importing.") # rubocop:disable Gitlab/RailsLogger
    false
  end

  def fail_import(message)
    project.import_state.mark_as_failed(message)
  end

  def template_import?
    project.gitlab_project_import?
  end
end

RepositoryImportWorker.prepend_if_ee('EE::RepositoryImportWorker')
