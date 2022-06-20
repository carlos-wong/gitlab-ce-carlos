# frozen_string_literal: true

module Gitlab
  # This module implements a simple rate limiter that can be used to throttle
  # certain actions. Unlike Rack Attack and Rack::Throttle, which operate at
  # the middleware level, this can be used at the controller or API level.
  # See CheckRateLimit concern for usage.
  module ApplicationRateLimiter
    InvalidKeyError = Class.new(StandardError)

    class << self
      # Application rate limits
      #
      # Threshold value can be either an Integer or a Proc
      # in order to not evaluate it's value every time this method is called
      # and only do that when it's needed.
      def rate_limits # rubocop:disable Metrics/AbcSize
        {
          issues_create:                { threshold: -> { application_settings.issues_create_limit }, interval: 1.minute },
          notes_create:                 { threshold: -> { application_settings.notes_create_limit }, interval: 1.minute },
          project_export:               { threshold: -> { application_settings.project_export_limit }, interval: 1.minute },
          project_download_export:      { threshold: -> { application_settings.project_download_export_limit }, interval: 1.minute },
          project_repositories_archive: { threshold: 5, interval: 1.minute },
          project_generate_new_export:  { threshold: -> { application_settings.project_export_limit }, interval: 1.minute },
          project_import:               { threshold: -> { application_settings.project_import_limit }, interval: 1.minute },
          project_testing_hook:         { threshold: 5, interval: 1.minute },
          play_pipeline_schedule:       { threshold: 1, interval: 1.minute },
          raw_blob:                     { threshold: -> { application_settings.raw_blob_request_limit }, interval: 1.minute },
          group_export:                 { threshold: -> { application_settings.group_export_limit }, interval: 1.minute },
          group_download_export:        { threshold: -> { application_settings.group_download_export_limit }, interval: 1.minute },
          group_import:                 { threshold: -> { application_settings.group_import_limit }, interval: 1.minute },
          group_testing_hook:           { threshold: 5, interval: 1.minute },
          profile_add_new_email:        { threshold: 5, interval: 1.minute },
          web_hook_calls:               { interval: 1.minute },
          users_get_by_id:              { threshold: -> { application_settings.users_get_by_id_limit }, interval: 10.minutes },
          username_exists:              { threshold: 20, interval: 1.minute },
          user_sign_up:                 { threshold: 20, interval: 1.minute },
          profile_resend_email_confirmation:  { threshold: 5, interval: 1.minute },
          profile_update_username:            { threshold: 10, interval: 1.minute },
          update_environment_canary_ingress:  { threshold: 1, interval: 1.minute },
          auto_rollback_deployment:           { threshold: 1, interval: 3.minutes },
          search_rate_limit:                  { threshold: -> { application_settings.search_rate_limit }, interval: 1.minute },
          search_rate_limit_unauthenticated:  { threshold: -> { application_settings.search_rate_limit_unauthenticated }, interval: 1.minute },
          gitlab_shell_operation:       { threshold: 600, interval: 1.minute },
          pipelines_create:             { threshold: 25, interval: 1.minute }
        }.freeze
      end

      # Increments the given key and returns true if the action should
      # be throttled.
      #
      # @param key [Symbol] Key attribute registered in `.rate_limits`
      # @param scope [Array<ActiveRecord>] Array of ActiveRecord models, Strings or Symbols to scope throttling to a specific request (e.g. per user per project)
      # @param threshold [Integer] Optional threshold value to override default one registered in `.rate_limits`
      # @param users_allowlist [Array<String>] Optional list of usernames to exclude from the limit. This param will only be functional if Scope includes a current user.
      # @param peek [Boolean] Optional. When true the key will not be incremented but the current throttled state will be returned.
      #
      # @return [Boolean] Whether or not a request should be throttled
      def throttled?(key, scope:, threshold: nil, users_allowlist: nil, peek: false)
        raise InvalidKeyError unless rate_limits[key]

        return false if scoped_user_in_allowlist?(scope, users_allowlist)

        threshold_value = threshold || threshold(key)

        return false if threshold_value == 0

        interval_value = interval(key)
        # `period_key` is based on the current time and interval so when time passes to the next interval
        # the key changes and the rate limit count starts again from 0.
        # Based on https://github.com/rack/rack-attack/blob/886ba3a18d13c6484cd511a4dc9b76c0d14e5e96/lib/rack/attack/cache.rb#L63-L68
        period_key, time_elapsed_in_period = Time.now.to_i.divmod(interval_value)
        cache_key = cache_key(key, scope, period_key)

        value = if peek
                  read(cache_key)
                else
                  increment(cache_key, interval_value, time_elapsed_in_period)
                end

        value > threshold_value
      end

      # Returns the current rate limited state without incrementing the count.
      #
      # @param key [Symbol] Key attribute registered in `.rate_limits`
      # @param scope [Array<ActiveRecord>] Array of ActiveRecord models to scope throttling to a specific request (e.g. per user per project)
      # @param threshold [Integer] Optional threshold value to override default one registered in `.rate_limits`
      # @param users_allowlist [Array<String>] Optional list of usernames to exclude from the limit. This param will only be functional if Scope includes a current user.
      #
      # @return [Boolean] Whether or not a request is currently throttled
      def peek(key, scope:, threshold: nil, users_allowlist: nil)
        throttled?(key, peek: true, scope: scope, threshold: threshold, users_allowlist: users_allowlist)
      end

      # Logs request using provided logger
      #
      # @param request [Http::Request] - Web request to be logged
      # @param type [Symbol] A symbol key that represents the request
      # @param current_user [User] Current user of the request, it can be nil
      # @param logger [Logger] Logger to log request to a specific log file. Defaults to Gitlab::AuthLogger
      def log_request(request, type, current_user, logger = Gitlab::AuthLogger)
        request_information = {
          message:        'Application_Rate_Limiter_Request',
          env:            type,
          remote_ip:      request.ip,
          request_method: request.request_method,
          path:           request.fullpath
        }

        if current_user
          request_information.merge!({
                                       user_id:  current_user.id,
                                       username: current_user.username
                                     })
        end

        logger.error(request_information)
      end

      private

      def threshold(key)
        value = rate_limit_value_by_key(key, :threshold)

        return value.call if value.is_a?(Proc)

        value.to_i
      end

      def interval(key)
        rate_limit_value_by_key(key, :interval).to_i
      end

      def rate_limit_value_by_key(key, setting)
        action = rate_limits[key]

        action[setting] if action
      end

      # Increments the rate limit count and returns the new count value.
      def increment(cache_key, interval_value, time_elapsed_in_period)
        # We add a 1 second buffer to avoid timing issues when we're at the end of a period
        expiry = interval_value - time_elapsed_in_period + 1

        ::Gitlab::Redis::RateLimiting.with do |redis|
          redis.pipelined do
            redis.incr(cache_key)
            redis.expire(cache_key, expiry)
          end.first
        end
      end

      # Returns the rate limit count.
      # Will be 0 if there is no data in the cache.
      def read(cache_key)
        ::Gitlab::Redis::RateLimiting.with do |redis|
          redis.get(cache_key).to_i
        end
      end

      def cache_key(key, scope, period_key)
        composed_key = [key, scope].flatten.compact

        serialized = composed_key.map do |obj|
          if obj.is_a?(String) || obj.is_a?(Symbol)
            "#{obj}"
          else
            "#{obj.class.model_name.to_s.underscore}:#{obj.id}"
          end
        end.join(":")

        "application_rate_limiter:#{serialized}:#{period_key}"
      end

      def application_settings
        Gitlab::CurrentSettings.current_application_settings
      end

      def scoped_user_in_allowlist?(scope, users_allowlist)
        return unless users_allowlist.present?

        scoped_user = [scope].flatten.find { |s| s.is_a?(User) }
        return unless scoped_user

        scoped_user.username.downcase.in?(users_allowlist)
      end
    end
  end
end
