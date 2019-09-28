# frozen_string_literal: true

class RedmineService < IssueTrackerService
  validates :project_url, :issues_url, :new_issue_url, presence: true, public_url: true, if: :activated?

  def default_title
    'Redmine'
  end

  def default_description
    s_('IssueTracker|Redmine issue tracker')
  end

  def self.to_param
    'redmine'
  end
end
