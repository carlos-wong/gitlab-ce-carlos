# frozen_string_literal: true

module Emails
  module Notes
    def note_commit_email(recipient_id, note_id, reason = nil)
      setup_note_mail(note_id, recipient_id)

      @commit = @note.noteable
      @target_url = project_commit_url(*note_target_url_options)
      mail_answer_note_thread(@commit, @note, note_thread_options(recipient_id, reason))
    end

    def note_issue_email(recipient_id, note_id, reason = nil)
      setup_note_mail(note_id, recipient_id)

      @issue = @note.noteable
      @target_url = project_issue_url(*note_target_url_options)
      mail_answer_note_thread(@issue, @note, note_thread_options(recipient_id, reason))
    end

    def note_merge_request_email(recipient_id, note_id, reason = nil)
      setup_note_mail(note_id, recipient_id)

      @merge_request = @note.noteable
      @target_url = project_merge_request_url(*note_target_url_options)
      mail_answer_note_thread(@merge_request, @note, note_thread_options(recipient_id, reason))
    end

    def note_snippet_email(recipient_id, note_id, reason = nil)
      setup_note_mail(note_id, recipient_id)
      @snippet = @note.noteable

      case @snippet
      when ProjectSnippet
        @target_url = project_snippet_url(*note_target_url_options)
      when Snippet
        @target_url = gitlab_snippet_url(@note.noteable)
      end

      mail_answer_note_thread(@snippet, @note, note_thread_options(recipient_id, reason))
    end

    private

    def note_target_url_options
      [@project || @group, @note.noteable, note_target_url_query_params]
    end

    def note_target_url_query_params
      { anchor: "note_#{@note.id}" }
    end

    def note_thread_options(recipient_id, reason)
      {
        from: sender(@note.author_id),
        to: User.find(recipient_id).notification_email_for(@project&.group || @group),
        subject: subject("#{@note.noteable.title} (#{@note.noteable.reference_link_text})"),
        'X-GitLab-NotificationReason' => reason
      }
    end

    def setup_note_mail(note_id, recipient_id)
      # `note_id` is a `Note` when originating in `NotifyPreview`
      @note = note_id.is_a?(Note) ? note_id : Note.find(note_id)
      @project = @note.project
      @group = @project.try(:group) || @note.noteable.try(:group)

      if (@project || @group) && @note.persisted?
        @sent_notification = SentNotification.record_note(@note, recipient_id, reply_key)
      end
    end
  end
end

Emails::Notes.prepend_if_ee('EE::Emails::Notes')
