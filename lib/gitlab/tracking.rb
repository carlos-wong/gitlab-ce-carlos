# frozen_string_literal: true

module Gitlab
  module Tracking
    class << self
      def enabled?
        snowplow.enabled?
      end

      def event(category, action, label: nil, property: nil, value: nil, context: [], project: nil, user: nil, namespace: nil, **extra) # rubocop:disable Metrics/ParameterLists
        contexts = [Tracking::StandardContext.new(project: project, user: user, namespace: namespace, **extra).to_context, *context]

        snowplow.event(category, action, label: label, property: property, value: value, context: contexts)
      rescue StandardError => error
        Gitlab::ErrorTracking.track_and_raise_for_dev_exception(error, snowplow_category: category, snowplow_action: action)
      end

      def definition(basename, category: nil, action: nil, label: nil, property: nil, value: nil, context: [], project: nil, user: nil, namespace: nil, **extra) # rubocop:disable Metrics/ParameterLists
        definition = YAML.load_file(Rails.root.join("config/events/#{basename}.yml"))

        dispatch_from_definition(definition, label: label, property: property, value: value, context: context, project: project, user: user, namespace: namespace, **extra)
      end

      def dispatch_from_definition(definition, **event_data)
        definition = definition.with_indifferent_access

        category ||= definition[:category]
        action ||= definition[:action]

        event(category, action, **event_data)
      end

      def options(group)
        snowplow.options(group)
      end

      def collector_hostname
        snowplow.hostname
      end

      def snowplow_micro_enabled?
        Rails.env.development? && Gitlab::Utils.to_boolean(ENV['SNOWPLOW_MICRO_ENABLE'])
      end

      private

      def snowplow
        @snowplow ||= if snowplow_micro_enabled?
                        Gitlab::Tracking::Destinations::SnowplowMicro.new
                      else
                        Gitlab::Tracking::Destinations::Snowplow.new
                      end
      end
    end
  end
end

Gitlab::Tracking.prepend_mod_with('Gitlab::Tracking')
