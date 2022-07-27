# frozen_string_literal: true

module Namespaces
  class InProductMarketingEmailsService
    TRACKS = {
      create: {
        interval_days: [1, 5, 10],
        completed_actions: [:created],
        incomplete_actions: [:git_write]
      },
      team_short: {
        interval_days: [1],
        completed_actions: [:git_write],
        incomplete_actions: [:user_added]
      },
      trial_short: {
        interval_days: [2],
        completed_actions: [:git_write],
        incomplete_actions: [:trial_started]
      },
      admin_verify: {
        interval_days: [3],
        completed_actions: [:git_write],
        incomplete_actions: [:pipeline_created]
      },
      verify: {
        interval_days: [4, 8, 13],
        completed_actions: [:git_write],
        incomplete_actions: [:pipeline_created]
      },
      trial: {
        interval_days: [1, 5, 10],
        completed_actions: [:git_write, :pipeline_created],
        incomplete_actions: [:trial_started]
      },
      team: {
        interval_days: [1, 5, 10],
        completed_actions: [:git_write, :pipeline_created, :trial_started],
        incomplete_actions: [:user_added]
      }
    }.freeze

    def self.email_count_for_track(track)
      interval_days = TRACKS.dig(track.to_sym, :interval_days)
      interval_days&.count || 0
    end

    def self.send_for_all_tracks_and_intervals
      TRACKS.each_key do |track|
        TRACKS[track][:interval_days].each do |interval|
          new(track, interval).execute
        end
      end
    end

    def initialize(track, interval)
      @track = track
      @interval = interval
      @sent_email_records = ::Users::InProductMarketingEmailRecords.new
    end

    def execute
      raise ArgumentError, "Track #{track} not defined" unless TRACKS.key?(track)

      groups_for_track.each_batch do |groups|
        groups.each do |group|
          send_email_for_group(group)
        end
      end
    end

    private

    attr_reader :track, :interval, :sent_email_records

    def send_email(user, group)
      NotificationService.new.in_product_marketing(user.id, group.id, track, series)
    end

    def send_email_for_group(group)
      users_for_group(group).each do |user|
        if can_perform_action?(user, group)
          send_email(user, group)
          sent_email_records.add(user, track: track, series: series)
        end
      end

      sent_email_records.save!
    end

    def groups_for_track
      onboarding_progress_scope = OnboardingProgress
        .completed_actions_with_latest_in_range(completed_actions, range)
        .incomplete_actions(incomplete_actions)

      # Filtering out sub-groups is a temporary fix to prevent calling
      # `.root_ancestor` on groups that are not root groups.
      # See https://gitlab.com/groups/gitlab-org/-/epics/5594 for more information.
      Group
        .top_most
        .with_onboarding_progress
        .merge(onboarding_progress_scope)
        .merge(subscription_scope)
    end

    def subscription_scope
      {}
    end

    # rubocop: disable CodeReuse/ActiveRecord
    def users_for_group(group)
      group.users
        .where(email_opted_in: true)
        .merge(Users::InProductMarketingEmail.without_track_and_series(track, series))
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def can_perform_action?(user, group)
      case track
      when :create, :verify
        user.can?(:create_projects, group)
      when :trial, :trial_short
        user.can?(:start_trial, group)
      when :team, :team_short
        user.can?(:admin_group_member, group)
      when :admin_verify
        user.can?(:admin_group, group)
      when :experience
        true
      end
    end

    def completed_actions
      TRACKS[track][:completed_actions]
    end

    def range
      date = (interval + 1).days.ago
      date.beginning_of_day..date.end_of_day
    end

    def incomplete_actions
      TRACKS[track][:incomplete_actions]
    end

    def series
      TRACKS[track][:interval_days].index(interval)
    end
  end
end

Namespaces::InProductMarketingEmailsService.prepend_mod
