# frozen_string_literal: true

class StageUpdateWorker # rubocop:disable Scalability/IdempotentWorker
  include ApplicationWorker
  include PipelineQueue

  queue_namespace :pipeline_processing
  urgency :high

  def perform(stage_id)
    Ci::Stage.find_by_id(stage_id)&.update_legacy_status
  end
end
