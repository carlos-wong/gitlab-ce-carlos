# frozen_string_literal: true

module Milestoneish
  def total_issues_count
    @total_issues_count ||= Milestones::IssuesCountService.new(self).count
  end

  def closed_issues_count
    @close_issues_count ||= Milestones::ClosedIssuesCountService.new(self).count
  end

  def opened_issues_count
    total_issues_count - closed_issues_count
  end

  def complete?
    total_issues_count > 0 && total_issues_count == closed_issues_count
  end

  def percent_complete
    closed_issues_count * 100 / total_issues_count
  rescue ZeroDivisionError
    0
  end

  def remaining_days
    return 0 if !due_date || expired?

    (due_date - Date.today).to_i
  end

  def elapsed_days
    return 0 if !start_date || start_date.future?

    (Date.today - start_date).to_i
  end

  def issues_visible_to_user(user)
    memoize_per_user(user, :issues_visible_to_user) do
      IssuesFinder.new(user, issues_finder_params)
        .execute.preload(:assignees).where(milestone_id: milestoneish_id)
    end
  end

  def issue_participants_visible_by_user(user)
    User.joins(:issue_assignees)
      .where('issue_assignees.issue_id' => issues_visible_to_user(user).select(:id))
      .distinct
  end

  def issue_labels_visible_by_user(user)
    Label.joins(:label_links)
      .where('label_links.target_id' => issues_visible_to_user(user).select(:id), 'label_links.target_type' => 'Issue')
      .distinct
  end

  def sorted_issues(user)
    issues_visible_to_user(user).preload_associated_models.sort_by_attribute('label_priority')
  end

  def sorted_merge_requests(user)
    merge_requests_visible_to_user(user).sort_by_attribute('label_priority')
  end

  def merge_requests_visible_to_user(user)
    memoize_per_user(user, :merge_requests_visible_to_user) do
      MergeRequestsFinder.new(user, issues_finder_params)
        .execute.where(milestone_id: milestoneish_id)
    end
  end

  def upcoming?
    start_date && start_date.future?
  end

  def expires_at
    if due_date
      if due_date.past?
        "expired on #{due_date.to_s(:medium)}"
      else
        "expires on #{due_date.to_s(:medium)}"
      end
    end
  end

  def expired?
    due_date && due_date.past?
  end

  def group_milestone?
    false
  end

  def project_milestone?
    false
  end

  def legacy_group_milestone?
    false
  end

  def dashboard_milestone?
    false
  end

  def global_milestone?
    false
  end

  def total_issue_time_spent
    @total_issue_time_spent ||= issues.joins(:timelogs).sum(:time_spent)
  end

  def human_total_issue_time_spent
    Gitlab::TimeTrackingFormatter.output(total_issue_time_spent)
  end

  def total_issue_time_estimate
    @total_issue_time_estimate ||= issues.sum(:time_estimate)
  end

  def human_total_issue_time_estimate
    Gitlab::TimeTrackingFormatter.output(total_issue_time_estimate)
  end

  private

  def memoize_per_user(user, method_name)
    memoized_users[method_name][user&.id] ||= yield
  end

  def memoized_users
    @memoized_users ||= Hash.new { |h, k| h[k] = {} }
  end

  # override in a class that includes this module to get a faster query
  # from IssuesFinder
  def issues_finder_params
    {}
  end
end
