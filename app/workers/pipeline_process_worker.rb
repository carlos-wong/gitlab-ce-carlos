# frozen_string_literal: true

class PipelineProcessWorker # rubocop:disable Scalability/IdempotentWorker
  include ApplicationWorker
  include PipelineQueue

  queue_namespace :pipeline_processing
  feature_category :continuous_integration
  urgency :high

  # rubocop: disable CodeReuse/ActiveRecord
  def perform(pipeline_id, build_ids = nil)
    Ci::Pipeline.find_by(id: pipeline_id).try do |pipeline|
      Ci::ProcessPipelineService
        .new(pipeline)
        .execute(build_ids)
    end
  end
  # rubocop: enable CodeReuse/ActiveRecord
end
