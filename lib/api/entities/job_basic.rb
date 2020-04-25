# frozen_string_literal: true

module API
  module Entities
    class JobBasic < Grape::Entity
      expose :id, :status, :stage, :name, :ref, :tag, :coverage, :allow_failure
      expose :created_at, :started_at, :finished_at
      expose :duration
      expose :user, with: Entities::User
      expose :commit, with: Entities::Commit
      expose :pipeline, with: Entities::PipelineBasic

      expose :web_url do |job, _options|
        Gitlab::Routing.url_helpers.project_job_url(job.project, job)
      end
    end
  end
end
