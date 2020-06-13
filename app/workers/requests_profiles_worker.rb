# frozen_string_literal: true

class RequestsProfilesWorker # rubocop:disable Scalability/IdempotentWorker
  include ApplicationWorker
  # rubocop:disable Scalability/CronWorkerContext
  # This worker does not perform work scoped to a context
  include CronjobQueue
  # rubocop:enable Scalability/CronWorkerContext

  feature_category :source_code_management

  def perform
    Gitlab::RequestProfiler.remove_all_profiles
  end
end
