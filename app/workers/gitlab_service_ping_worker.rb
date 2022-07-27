# frozen_string_literal: true

class GitlabServicePingWorker # rubocop:disable Scalability/IdempotentWorker
  LEASE_KEY = 'gitlab_service_ping_worker:ping'
  LEASE_TIMEOUT = 86400

  include ApplicationWorker

  data_consistency :always
  include CronjobQueue # rubocop:disable Scalability/CronWorkerContext
  include Gitlab::ExclusiveLeaseHelpers

  feature_category :service_ping
  worker_resource_boundary :cpu
  sidekiq_options retry: 3, dead: false
  sidekiq_retry_in { |count| (count + 1) * 8.hours.to_i }

  def perform
    # Disable service ping for GitLab.com
    # See https://gitlab.com/gitlab-org/gitlab/-/issues/292929 for details
    return if Gitlab.com?

    # Multiple Sidekiq workers could run this. We should only do this at most once a day.
    in_lock(LEASE_KEY, ttl: LEASE_TIMEOUT) do
      # Splay the request over a minute to avoid thundering herd problems.
      sleep(rand(0.0..60.0).round(3))

      ServicePing::SubmitService.new(payload: usage_data).execute
    end
  end

  def usage_data
    ServicePing::BuildPayload.new.execute.tap do |payload|
      record = {
        recorded_at: payload[:recorded_at],
        payload: payload,
        created_at: Time.current,
        updated_at: Time.current
      }

      RawUsageData.upsert(record, unique_by: :recorded_at)
    end
  rescue StandardError => err
    Gitlab::ErrorTracking.track_and_raise_for_dev_exception(err)
    nil
  end
end
