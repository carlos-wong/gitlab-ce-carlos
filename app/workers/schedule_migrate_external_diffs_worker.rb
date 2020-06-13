# frozen_string_literal: true

class ScheduleMigrateExternalDiffsWorker # rubocop:disable Scalability/IdempotentWorker
  include ApplicationWorker
  # rubocop:disable Scalability/CronWorkerContext:
  # This schedules the `MigrateExternalDiffsWorker`
  # issue for adding context: https://gitlab.com/gitlab-org/gitlab/issues/202100
  include CronjobQueue
  # rubocop:enable Scalability/CronWorkerContext:

  include Gitlab::ExclusiveLeaseHelpers

  feature_category :source_code_management

  def perform
    in_lock(self.class.name.underscore, ttl: 2.hours, retries: 0) do
      MergeRequests::MigrateExternalDiffsService.enqueue!
    end
  rescue Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError
  end
end
