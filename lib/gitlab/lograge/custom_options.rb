# frozen_string_literal: true

module Gitlab
  module Lograge
    module CustomOptions
      LIMITED_ARRAY_SENTINEL = { key: 'truncated', value: '...' }.freeze
      IGNORE_PARAMS = Set.new(%w(controller action format)).freeze

      def self.call(event)
        params = event
          .payload[:params]
          .each_with_object([]) { |(k, v), array| array << { key: k, value: v } unless IGNORE_PARAMS.include?(k) }

        payload = {
          time: Time.now.utc.iso8601(3),
          params: Gitlab::Utils::LogLimitedArray.log_limited_array(params, sentinel: LIMITED_ARRAY_SENTINEL),
          remote_ip: event.payload[:remote_ip],
          user_id: event.payload[:user_id],
          username: event.payload[:username],
          ua: event.payload[:ua],
          queue_duration: event.payload[:queue_duration]
        }

        ::Gitlab::InstrumentationHelper.add_instrumentation_data(payload)

        payload[:response] = event.payload[:response] if event.payload[:response]
        payload[:etag_route] = event.payload[:etag_route] if event.payload[:etag_route]
        payload[Labkit::Correlation::CorrelationId::LOG_KEY] = Labkit::Correlation::CorrelationId.current_id

        if cpu_s = Gitlab::Metrics::System.thread_cpu_duration(::Gitlab::RequestContext.instance.start_thread_cpu_time)
          payload[:cpu_s] = cpu_s
        end

        # https://github.com/roidrage/lograge#logging-errors--exceptions
        exception = event.payload[:exception_object]

        ::Gitlab::ExceptionLogFormatter.format!(exception, payload)

        payload
      end
    end
  end
end
