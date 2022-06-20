# frozen_string_literal: true

module Mutations
  module Ci
    module Pipeline
      class Cancel < Base
        graphql_name 'PipelineCancel'

        authorize :update_pipeline

        def resolve(id:)
          pipeline = authorized_find!(id: id)

          if pipeline.cancelable?
            pipeline.cancel_running
            pipeline.cancel

            { success: true, errors: [] }
          else
            { success: false, errors: ['Pipeline is not cancelable'] }
          end
        end
      end
    end
  end
end
