# frozen_string_literal: true

module Prometheus
  class ProxyService < BaseService
    include ReactiveCaching
    include Gitlab::Utils::StrongMemoize

    self.reactive_cache_key = ->(service) { service.cache_key }
    self.reactive_cache_lease_timeout = 30.seconds
    self.reactive_cache_refresh_interval = 30.seconds
    self.reactive_cache_lifetime = 1.minute
    self.reactive_cache_worker_finder = ->(_id, *args) { from_cache(*args) }

    attr_accessor :proxyable, :method, :path, :params

    PROXY_SUPPORT = {
      'query' => {
        method: ['GET'],
        params: %w(query time timeout)
      },
      'query_range' => {
        method: ['GET'],
        params: %w(query start end step timeout)
      }
    }.freeze

    def self.from_cache(proxyable_class_name, proxyable_id, method, path, params)
      proxyable_class = begin
        proxyable_class_name.constantize
      rescue NameError
        nil
      end
      return unless proxyable_class

      proxyable = proxyable_class.find(proxyable_id)

      new(proxyable, method, path, params)
    end

    # proxyable can be any model which responds to .prometheus_adapter
    # like Environment.
    def initialize(proxyable, method, path, params)
      @proxyable = proxyable
      @path = path

      # Convert ActionController::Parameters to hash because reactive_cache_worker
      # does not play nice with ActionController::Parameters.
      @params = filter_params(params, path).to_hash

      @method = method
    end

    def id
      nil
    end

    def execute
      return cannot_proxy_response unless can_proxy?
      return no_prometheus_response unless can_query?

      with_reactive_cache(*cache_key) do |result|
        result
      end
    end

    def calculate_reactive_cache(proxyable_class_name, proxyable_id, method, path, params)
      return no_prometheus_response unless can_query?

      response = prometheus_client_wrapper.proxy(path, params)

      success(http_status: response.code, body: response.body)
    rescue Gitlab::PrometheusClient::Error => err
      service_unavailable_response(err)
    end

    def cache_key
      [@proxyable.class.name, @proxyable.id, @method, @path, @params]
    end

    private

    def service_unavailable_response(exception)
      error(exception.message, :service_unavailable)
    end

    def no_prometheus_response
      error('No prometheus server found', :service_unavailable)
    end

    def cannot_proxy_response
      error('Proxy support for this API is not available currently')
    end

    def prometheus_adapter
      strong_memoize(:prometheus_adapter) do
        @proxyable.prometheus_adapter
      end
    end

    def prometheus_client_wrapper
      prometheus_adapter&.prometheus_client_wrapper
    end

    def can_query?
      prometheus_adapter&.can_query?
    end

    def filter_params(params, path)
      params.slice(*PROXY_SUPPORT.dig(path, :params))
    end

    def can_proxy?
      PROXY_SUPPORT.dig(@path, :method)&.include?(@method)
    end
  end
end
