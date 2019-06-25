# frozen_string_literal: true

module Emails
  module MergeRequests
    def new_merge_request_email(recipient_id, merge_request_id, reason = nil)
      setup_merge_request_mail(merge_request_id, recipient_id, present: true)

      mail_new_thread(@merge_request, merge_request_thread_options(@merge_request.author_id, recipient_id, reason))
    end

    def new_mention_in_merge_request_email(recipient_id, merge_request_id, updated_by_user_id, reason = nil)
      setup_merge_request_mail(merge_request_id, recipient_id, present: true)

      mail_answer_thread(@merge_request, merge_request_thread_options(updated_by_user_id, recipient_id, reason))
    end

    def push_to_merge_request_email(recipient_id, merge_request_id, updated_by_user_id, reason = nil, new_commits: [], existing_commits: [])
      setup_merge_request_mail(merge_request_id, recipient_id)
      @new_commits = new_commits
      @existing_commits = existing_commits
      @updated_by_user = User.find(updated_by_user_id)

      mail_answer_thread(@merge_request, merge_request_thread_options(updated_by_user_id, recipient_id, reason))
    end

    # rubocop: disable CodeReuse/ActiveRecord
    def reassigned_merge_request_email(recipient_id, merge_request_id, previous_assignee_ids, updated_by_user_id, reason = nil)
      setup_merge_request_mail(merge_request_id, recipient_id)

      @previous_assignees = []
      @previous_assignees = User.where(id: previous_assignee_ids) if previous_assignee_ids.any?

      mail_answer_thread(@merge_request, merge_request_thread_options(updated_by_user_id, recipient_id, reason))
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def relabeled_merge_request_email(recipient_id, merge_request_id, label_names, updated_by_user_id, reason = nil)
      setup_merge_request_mail(merge_request_id, recipient_id)

      @label_names = label_names
      @labels_url = project_labels_url(@project)
      mail_answer_thread(@merge_request, merge_request_thread_options(updated_by_user_id, recipient_id, reason))
    end

    def removed_milestone_merge_request_email(recipient_id, merge_request_id, updated_by_user_id, reason = nil)
      setup_merge_request_mail(merge_request_id, recipient_id)

      mail_answer_thread(@merge_request, merge_request_thread_options(updated_by_user_id, recipient_id, reason))
    end

    def changed_milestone_merge_request_email(recipient_id, merge_request_id, milestone, updated_by_user_id, reason = nil)
      setup_merge_request_mail(merge_request_id, recipient_id)

      @milestone = milestone
      @milestone_url = milestone_url(@milestone)
      mail_answer_thread(@merge_request, merge_request_thread_options(updated_by_user_id, recipient_id, reason).merge({
        template_name: 'changed_milestone_email'
      }))
    end

    def closed_merge_request_email(recipient_id, merge_request_id, updated_by_user_id, reason: nil, closed_via: nil)
      setup_merge_request_mail(merge_request_id, recipient_id)

      @updated_by = User.find(updated_by_user_id)
      mail_answer_thread(@merge_request, merge_request_thread_options(updated_by_user_id, recipient_id, reason))
    end

    def merged_merge_request_email(recipient_id, merge_request_id, updated_by_user_id, reason: nil, closed_via: nil)
      setup_merge_request_mail(merge_request_id, recipient_id)

      mail_answer_thread(@merge_request, merge_request_thread_options(updated_by_user_id, recipient_id, reason))
    end

    def merge_request_status_email(recipient_id, merge_request_id, status, updated_by_user_id, reason = nil)
      setup_merge_request_mail(merge_request_id, recipient_id)

      @mr_status = status
      @updated_by = User.find(updated_by_user_id)
      mail_answer_thread(@merge_request, merge_request_thread_options(updated_by_user_id, recipient_id, reason))
    end

    def merge_request_unmergeable_email(recipient_id, merge_request_id, reason = nil)
      setup_merge_request_mail(merge_request_id, recipient_id)

      mail_answer_thread(@merge_request, merge_request_thread_options(@merge_request.author_id, recipient_id, reason))
    end

    def resolved_all_discussions_email(recipient_id, merge_request_id, resolved_by_user_id, reason = nil)
      setup_merge_request_mail(merge_request_id, recipient_id)

      @resolved_by = User.find(resolved_by_user_id)
      mail_answer_thread(@merge_request, merge_request_thread_options(resolved_by_user_id, recipient_id, reason))
    end

    private

    def setup_merge_request_mail(merge_request_id, recipient_id, present: false)
      @merge_request = MergeRequest.find(merge_request_id)
      @project = @merge_request.project
      @target_url = project_merge_request_url(@project, @merge_request)

      if present
        recipient = User.find(recipient_id)
        @mr_presenter = @merge_request.present(current_user: recipient)
      end

      @sent_notification = SentNotification.record(@merge_request, recipient_id, reply_key)
    end

    def merge_request_thread_options(sender_id, recipient_id, reason = nil)
      {
        from: sender(sender_id),
        to: recipient(recipient_id, @project.group),
        subject: subject("#{@merge_request.title} (#{@merge_request.to_reference})"),
        'X-GitLab-NotificationReason' => reason
      }
    end
  end
end
