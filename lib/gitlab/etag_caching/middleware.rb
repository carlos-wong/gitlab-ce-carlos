# frozen_string_literal: true

module Gitlab
  module EtagCaching
    class Middleware
      def initialize(app)
        @app = app
      end

      def call(env)
        request = ActionDispatch::Request.new(env)
        route = Gitlab::EtagCaching::Router.match(request.path_info)
        return @app.call(env) unless route

        track_event(:etag_caching_middleware_used, route)

        etag, cached_value_present = get_etag(request)
        if_none_match = env['HTTP_IF_NONE_MATCH']

        if if_none_match == etag
          handle_cache_hit(etag, route, request)
        else
          track_cache_miss(if_none_match, cached_value_present, route)

          status, headers, body = @app.call(env)
          headers['ETag'] = etag
          [status, headers, body]
        end
      end

      private

      def get_etag(request)
        cache_key = request.path
        store = Gitlab::EtagCaching::Store.new
        current_value = store.get(cache_key)
        cached_value_present = current_value.present?

        unless cached_value_present
          current_value = store.touch(cache_key, only_if_missing: true)
        end

        [weak_etag_format(current_value), cached_value_present]
      end

      def weak_etag_format(value)
        %Q{W/"#{value}"}
      end

      def handle_cache_hit(etag, route, request)
        track_event(:etag_caching_cache_hit, route)

        status_code = Gitlab::PollingInterval.polling_enabled? ? 304 : 429

        add_instrument_for_cache_hit(status_code, route, request)

        [status_code, { 'ETag' => etag, 'X-Gitlab-From-Cache' => 'true' }, []]
      end

      def track_cache_miss(if_none_match, cached_value_present, route)
        if if_none_match.blank?
          track_event(:etag_caching_header_missing, route)
        elsif !cached_value_present
          track_event(:etag_caching_key_not_found, route)
        else
          track_event(:etag_caching_resource_changed, route)
        end
      end

      def track_event(name, route)
        Gitlab::Metrics.add_event(name, endpoint: route.name)
      end

      def add_instrument_for_cache_hit(status, route, request)
        payload = {
          etag_route: route.name,
          params:     request.filtered_parameters,
          headers:    request.headers,
          format:     request.format.ref,
          method:     request.request_method,
          path:       request.filtered_path,
          status:     status
        }

        ActiveSupport::Notifications.instrument(
          "process_action.action_controller", payload)
      end
    end
  end
end
