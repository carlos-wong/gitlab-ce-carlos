# frozen_string_literal: true

class ExpireJobCacheWorker
  include ApplicationWorker
  include PipelineQueue

  queue_namespace :pipeline_cache
  urgency :high
  idempotent!

  # rubocop: disable CodeReuse/ActiveRecord
  def perform(job_id)
    job = CommitStatus.joins(:pipeline, :project).find_by(id: job_id)
    return unless job

    pipeline = job.pipeline
    project = job.project

    Gitlab::EtagCaching::Store.new.tap do |store|
      store.touch(project_pipeline_path(project, pipeline))
      store.touch(project_job_path(project, job))
    end
  end
  # rubocop: enable CodeReuse/ActiveRecord

  private

  def project_pipeline_path(project, pipeline)
    Gitlab::Routing.url_helpers.project_pipeline_path(project, pipeline, format: :json)
  end

  def project_job_path(project, job)
    Gitlab::Routing.url_helpers.project_build_path(project, job.id, format: :json)
  end
end
