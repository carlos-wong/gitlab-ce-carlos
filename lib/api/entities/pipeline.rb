# frozen_string_literal: true

module API
  module Entities
    class Pipeline < Entities::PipelineBasic
      expose :before_sha, :tag, :yaml_errors

      expose :user, with: Entities::UserBasic
      expose :created_at, :updated_at, :started_at, :finished_at, :committed_at
      expose :duration
      expose :coverage
      expose :detailed_status, using: DetailedStatusEntity do |pipeline, options|
        pipeline.detailed_status(options[:current_user])
      end
    end
  end
end
