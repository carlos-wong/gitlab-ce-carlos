# frozen_string_literal: true

module Gitlab
  module SidekiqMiddleware
    class ClientMetrics < SidekiqMiddleware::Metrics
      ENQUEUED = :sidekiq_enqueued_jobs_total

      def initialize
        @metrics = init_metrics
      end

      def call(worker_class, _job, queue, _redis_pool)
        # worker_class can either be the string or class of the worker being enqueued.
        worker_class = worker_class.safe_constantize if worker_class.respond_to?(:safe_constantize)
        labels = create_labels(worker_class, queue)

        @metrics.fetch(ENQUEUED).increment(labels, 1)

        yield
      end

      private

      def init_metrics
        {
          ENQUEUED => ::Gitlab::Metrics.counter(ENQUEUED, 'Sidekiq jobs enqueued')
        }
      end
    end
  end
end
