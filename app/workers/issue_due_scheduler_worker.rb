# frozen_string_literal: true

class IssueDueSchedulerWorker
  include ApplicationWorker
  include CronjobQueue

  feature_category :issue_tracking

  # rubocop: disable CodeReuse/ActiveRecord
  def perform
    project_ids = Issue.opened.due_tomorrow.group(:project_id).pluck(:project_id).map { |id| [id] }

    MailScheduler::IssueDueWorker.bulk_perform_async(project_ids)
  end
  # rubocop: enable CodeReuse/ActiveRecord
end
