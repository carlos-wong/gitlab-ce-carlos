# frozen_string_literal: true

module Gitlab
  module ExternalAuthorization
    class Cache
      VALIDITY_TIME = 6.hours

      def initialize(user, label)
        @user, @label = user, label
      end

      def load
        @access, @reason, @refreshed_at = ::Gitlab::Redis::Cache.with do |redis|
          redis.hmget(cache_key, :access, :reason, :refreshed_at)
        end

        [access, reason, refreshed_at]
      end

      def store(new_access, new_reason, new_refreshed_at)
        ::Gitlab::Redis::Cache.with do |redis|
          redis.pipelined do
            redis.mapped_hmset(
              cache_key,
              {
                access: new_access.to_s,
                reason: new_reason.to_s,
                refreshed_at: new_refreshed_at.to_s
              }
            )

            redis.expire(cache_key, VALIDITY_TIME)
          end
        end
      end

      private

      def access
        ::Gitlab::Utils.to_boolean(@access)
      end

      def reason
        # `nil` if the cached value was an empty string
        return unless @reason.present?

        @reason
      end

      def refreshed_at
        # Don't try to parse a time if there was no cache
        return unless @refreshed_at.present?

        Time.parse(@refreshed_at)
      end

      def cache_key
        "external_authorization:user-#{@user.id}:label-#{@label}"
      end
    end
  end
end
