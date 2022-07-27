# frozen_string_literal: true

module Users
  class ActivityService
    LEASE_TIMEOUT = 1.minute.to_i

    def initialize(author)
      @user = if author.respond_to?(:username)
                author
              elsif author.respond_to?(:user)
                author.user
              end

      @user = nil unless @user.is_a?(User)
    end

    def execute
      return unless @user

      ::Gitlab::Database::LoadBalancing::Session.without_sticky_writes { record_activity }
    end

    private

    def record_activity
      return if Gitlab::Database.read_only?

      today = Date.today

      return if @user.last_activity_on == today

      lease = Gitlab::ExclusiveLease.new("activity_service:#{@user.id}",
                                         timeout: LEASE_TIMEOUT)
      return unless lease.try_obtain

      @user.update_attribute(:last_activity_on, today)

      Gitlab::UsageDataCounters::HLLRedisCounter.track_event('unique_active_user', values: @user.id)
    end
  end
end
