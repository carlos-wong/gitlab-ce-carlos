# frozen_string_literal: true

module Gitlab
  module SidekiqConfig
    class Worker
      include Comparable

      attr_reader :klass
      delegate :feature_category_not_owned?, :get_feature_category,
               :get_urgency, :get_weight, :get_worker_resource_boundary,
               :idempotent?, :queue, :queue_namespace,
               :worker_has_external_dependencies?,
               to: :klass

      def initialize(klass, ee:)
        @klass = klass
        @ee = ee
      end

      def ee?
        @ee
      end

      def ==(other)
        to_yaml == case other
                   when self.class
                     other.to_yaml
                   else
                     other
                   end
      end

      def <=>(other)
        to_sort <=> other.to_sort
      end

      # Put namespaced queues first
      def to_sort
        [queue_namespace ? 0 : 1, queue]
      end

      # YAML representation
      def encode_with(coder)
        coder.represent_map(nil, to_yaml)
      end

      def to_yaml
        {
          name: queue,
          feature_category: get_feature_category,
          has_external_dependencies: worker_has_external_dependencies?,
          urgency: get_urgency,
          resource_boundary: get_worker_resource_boundary,
          weight: get_weight,
          idempotent: idempotent?
        }
      end

      def namespace_and_weight
        [queue_namespace, get_weight]
      end

      def queue_and_weight
        [queue, get_weight]
      end
    end
  end
end
