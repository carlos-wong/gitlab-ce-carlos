# frozen_string_literal: true

module Gitlab
  module SidekiqLogging
    module LogsJobs
      def base_message(payload)
        "#{payload['class']} JID-#{payload['jid']}"
      end

      def parse_job(job)
        # Error information from the previous try is in the payload for
        # displaying in the Sidekiq UI, but is very confusing in logs!
        job = job.except('error_backtrace', 'error_class', 'error_message')

        # Add process id params
        job['pid'] = ::Process.pid

        job.delete('args') unless ENV['SIDEKIQ_LOG_ARGUMENTS']
        job['args'] = Gitlab::Utils::LogLimitedArray.log_limited_array(job['args'].map(&:to_s)) if job['args']

        job
      end
    end
  end
end
