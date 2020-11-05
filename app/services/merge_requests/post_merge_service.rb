# frozen_string_literal: true

module MergeRequests
  # PostMergeService class
  #
  # Mark existing merge request as merged
  # and execute all hooks and notifications
  #
  class PostMergeService < MergeRequests::BaseService
    def execute(merge_request)
      merge_request.mark_as_merged
      close_issues(merge_request)
      todo_service.merge_merge_request(merge_request, current_user)
      create_event(merge_request)
      create_note(merge_request)
      notification_service.merge_mr(merge_request, current_user)
      execute_hooks(merge_request, 'merge')
      invalidate_cache_counts(merge_request, users: merge_request.assignees)
      merge_request.update_project_counter_caches
      delete_non_latest_diffs(merge_request)
      cleanup_environments(merge_request)
    end

    private

    def close_issues(merge_request)
      return unless merge_request.target_branch == project.default_branch

      closed_issues = merge_request.visible_closing_issues_for(current_user)

      closed_issues.each do |issue|
        Issues::CloseService.new(project, current_user).execute(issue, commit: merge_request)
      end
    end

    def delete_non_latest_diffs(merge_request)
      DeleteNonLatestDiffsService.new(merge_request).execute
    end

    def create_merge_event(merge_request, current_user)
      EventCreateService.new.merge_mr(merge_request, current_user)
    end

    def create_event(merge_request)
      # Making sure MergeRequest::Metrics updates are in sync with
      # Event creation.
      Event.transaction do
        merge_event = create_merge_event(merge_request, current_user)
        merge_request_metrics_service(merge_request).merge(merge_event)
      end
    end
  end
end

MergeRequests::PostMergeService.prepend_if_ee('EE::MergeRequests::PostMergeService')
