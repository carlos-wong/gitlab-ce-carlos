# frozen_string_literal: true

module API
  module Entities
    class PipelineBasic < Grape::Entity
      expose :id, :sha, :ref, :status
      expose :created_at, :updated_at

      expose :web_url do |pipeline, _options|
        Gitlab::Routing.url_helpers.project_pipeline_url(pipeline.project, pipeline)
      end
    end
  end
end
