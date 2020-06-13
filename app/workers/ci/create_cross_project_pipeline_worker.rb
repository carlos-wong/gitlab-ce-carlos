# frozen_string_literal: true

module Ci
  class CreateCrossProjectPipelineWorker # rubocop:disable Scalability/IdempotentWorker
    include ::ApplicationWorker
    include ::PipelineQueue

    worker_resource_boundary :cpu

    def perform(bridge_id)
      ::Ci::Bridge.find_by_id(bridge_id).try do |bridge|
        ::Ci::CreateCrossProjectPipelineService
          .new(bridge.project, bridge.user)
          .execute(bridge)
      end
    end
  end
end
