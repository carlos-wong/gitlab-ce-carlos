# frozen_string_literal: true

module Gitlab
  class ContributionsCalendar
    attr_reader :contributor
    attr_reader :current_user
    attr_reader :projects

    def initialize(contributor, current_user = nil)
      @contributor = contributor
      @current_user = current_user
      @projects = if @contributor.include_private_contributions?
                    ContributedProjectsFinder.new(@contributor).execute(@contributor)
                  else
                    ContributedProjectsFinder.new(contributor).execute(current_user)
                  end
    end

    # rubocop: disable CodeReuse/ActiveRecord
    def activity_dates
      return @activity_dates if @activity_dates.present?

      # Can't use Event.contributions here because we need to check 3 different
      # project_features for the (currently) 3 different contribution types
      date_from = 1.year.ago
      repo_events = event_counts(date_from, :repository)
        .having(action: Event::PUSHED)
      issue_events = event_counts(date_from, :issues)
        .having(action: [Event::CREATED, Event::CLOSED], target_type: "Issue")
      mr_events = event_counts(date_from, :merge_requests)
        .having(action: [Event::MERGED, Event::CREATED, Event::CLOSED], target_type: "MergeRequest")
      note_events = event_counts(date_from, :merge_requests)
        .having(action: [Event::COMMENTED])

      events = Event
        .from_union([repo_events, issue_events, mr_events, note_events])
        .map(&:attributes)

      @activity_dates = events.each_with_object(Hash.new {|h, k| h[k] = 0 }) do |event, activities|
        activities[event["date"]] += event["total_amount"]
      end
    end
    # rubocop: enable CodeReuse/ActiveRecord

    # rubocop: disable CodeReuse/ActiveRecord
    def events_by_date(date)
      return Event.none unless can_read_cross_project?

      Event.contributions.where(author_id: contributor.id)
        .where(created_at: date.beginning_of_day..date.end_of_day)
        .where(project_id: projects)
        .with_associations
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def starting_year
      1.year.ago.year
    end

    def starting_month
      Date.current.month
    end

    private

    def can_read_cross_project?
      Ability.allowed?(current_user, :read_cross_project)
    end

    # rubocop: disable CodeReuse/ActiveRecord
    def event_counts(date_from, feature)
      t = Event.arel_table

      # re-running the contributed projects query in each union is expensive, so
      # use IN(project_ids...) instead. It's the intersection of two users so
      # the list will be (relatively) short
      @contributed_project_ids ||= projects.distinct.pluck(:id)
      authed_projects = Project.where(id: @contributed_project_ids)
        .with_feature_available_for_user(feature, current_user)
        .reorder(nil)
        .select(:id)

      conditions = t[:created_at].gteq(date_from.beginning_of_day)
        .and(t[:created_at].lteq(Date.current.end_of_day))
        .and(t[:author_id].eq(contributor.id))

      date_interval = if Gitlab::Database.postgresql?
                        "INTERVAL '#{Time.zone.now.utc_offset} seconds'"
                      else
                        "INTERVAL #{Time.zone.now.utc_offset} SECOND"
                      end

      Event.reorder(nil)
        .select(t[:project_id], t[:target_type], t[:action], "date(created_at + #{date_interval}) AS date", 'count(id) as total_amount')
        .group(t[:project_id], t[:target_type], t[:action], "date(created_at + #{date_interval})")
        .where(conditions)
        .where("events.project_id in (#{authed_projects.to_sql})") # rubocop:disable GitlabSecurity/SqlInjection
    end
    # rubocop: enable CodeReuse/ActiveRecord
  end
end
