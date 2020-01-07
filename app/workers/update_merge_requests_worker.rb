# frozen_string_literal: true

class UpdateMergeRequestsWorker
  include ApplicationWorker

  feature_category :source_code_management
  latency_sensitive_worker!
  worker_resource_boundary :cpu

  LOG_TIME_THRESHOLD = 90 # seconds

  # rubocop: disable CodeReuse/ActiveRecord
  def perform(project_id, user_id, oldrev, newrev, ref)
    project = Project.find_by(id: project_id)
    return unless project

    user = User.find_by(id: user_id)
    return unless user

    # TODO: remove this benchmarking when we have rich logging
    time = Benchmark.measure do
      MergeRequests::RefreshService.new(project, user).execute(oldrev, newrev, ref)
    end

    args_log = [
      "elapsed=#{time.real}",
      "project_id=#{project_id}",
      "user_id=#{user_id}",
      "oldrev=#{oldrev}",
      "newrev=#{newrev}",
      "ref=#{ref}"
    ].join(',')

    Rails.logger.info("UpdateMergeRequestsWorker#perform #{args_log}") if time.real > LOG_TIME_THRESHOLD # rubocop:disable Gitlab/RailsLogger
  end
  # rubocop: enable CodeReuse/ActiveRecord
end
