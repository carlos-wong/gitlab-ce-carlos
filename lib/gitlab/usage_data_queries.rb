# frozen_string_literal: true

module Gitlab
  # This class is used by the `gitlab:usage_data:dump_sql` rake tasks to output SQL instead of running it.
  # See https://gitlab.com/gitlab-org/gitlab/-/merge_requests/41091
  class UsageDataQueries < UsageData
    class << self
      def add_metric(metric, time_frame: 'none', options: {})
        metric_class = "Gitlab::Usage::Metrics::Instrumentations::#{metric}".constantize

        metric_class.new(time_frame: time_frame, options: options).instrumentation
      end

      def count(relation, column = nil, *args, **kwargs)
        Gitlab::Usage::Metrics::Query.for(:count, relation, column)
      end

      def distinct_count(relation, column = nil, *args, **kwargs)
        Gitlab::Usage::Metrics::Query.for(:distinct_count, relation, column)
      end

      def sum(relation, column, *args, **kwargs)
        Gitlab::Usage::Metrics::Query.for(:sum, relation, column)
      end

      # rubocop: disable CodeReuse/ActiveRecord
      def histogram(relation, column, buckets:, bucket_size: buckets.size)
        Gitlab::Usage::Metrics::Query.for(:histogram, relation, column, buckets: buckets, bucket_size: bucket_size)
      end
      # rubocop: enable CodeReuse/ActiveRecord

      # For estimated distinct count use exact query instead of hll
      # buckets query, because it can't be used to obtain estimations without
      # supplementary ruby code present in Gitlab::Database::PostgresHll::BatchDistinctCounter
      def estimate_batch_distinct_count(relation, column = nil, *args, **kwargs)
        Gitlab::Usage::Metrics::Query.for(:estimate_batch_distinct_count, relation, column)
      end

      def add(*args)
        'SELECT ' + args.map { |arg| "(#{arg})" }.join(' + ')
      end

      def maximum_id(model, column = nil)
        # no-op: shadowing super for performance reasons
      end

      def minimum_id(model, column = nil)
        # no-op: shadowing super for performance reasons
      end

      def alt_usage_data(value = nil, fallback: FALLBACK, &block)
        if block_given?
          { alt_usage_data_block: "non-SQL usage data block" }
        else
          { alt_usage_data_value: value }
        end
      end

      def redis_usage_data(counter = nil, &block)
        if block_given?
          { redis_usage_data_block: "non-SQL usage data block" }
        elsif counter.present?
          { redis_usage_data_counter: counter.to_s }
        end
      end

      def jira_integration_data
        {
          projects_jira_server_active: 0,
          projects_jira_cloud_active: 0
        }
      end

      def epics_deepest_relationship_level
        { epics_deepest_relationship_level: 0 }
      end

      def topology_usage_data
        {
          duration_s: 0,
          failures: []
        }
      end
    end
  end
end
