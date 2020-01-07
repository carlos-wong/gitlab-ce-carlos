# frozen_string_literal: true

class PipelineUpdateWorker
  include ApplicationWorker
  include PipelineQueue

  queue_namespace :pipeline_processing
  latency_sensitive_worker!

  # rubocop: disable CodeReuse/ActiveRecord
  def perform(pipeline_id)
    Ci::Pipeline.find_by(id: pipeline_id)
      .try(:update_status)
  end
  # rubocop: enable CodeReuse/ActiveRecord
end
