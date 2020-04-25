# frozen_string_literal: true

module API
  module Entities
    module JobRequest
      class JobInfo < Grape::Entity
        expose :name, :stage
        expose :project_id, :project_name
      end
    end
  end
end
