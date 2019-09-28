# frozen_string_literal: true

module Issuable
  class CommonSystemNotesService < ::BaseService
    attr_reader :issuable

    def execute(issuable, old_labels: [], is_update: true)
      @issuable = issuable

      if is_update
        if issuable.previous_changes.include?('title')
          create_title_change_note(issuable.previous_changes['title'].first)
        end

        handle_description_change_note

        handle_time_tracking_note if issuable.is_a?(TimeTrackable)
        create_discussion_lock_note if issuable.previous_changes.include?('discussion_locked')
      end

      create_due_date_note if issuable.previous_changes.include?('due_date')
      create_milestone_note if issuable.previous_changes.include?('milestone_id')
      create_labels_note(old_labels) if old_labels && issuable.labels != old_labels
    end

    private

    def handle_time_tracking_note
      if issuable.previous_changes.include?('time_estimate')
        create_time_estimate_note
      end

      if issuable.time_spent?
        create_time_spent_note
      end
    end

    def handle_description_change_note
      if issuable.previous_changes.include?('description')
        if issuable.tasks? && issuable.updated_tasks.any?
          create_task_status_note
        else
          # TODO: Show this note if non-task content was modified.
          # https://gitlab.com/gitlab-org/gitlab-foss/issues/33577
          create_description_change_note
        end
      end
    end

    def create_wip_note(old_title)
      return unless issuable.is_a?(MergeRequest)

      if MergeRequest.work_in_progress?(old_title) != issuable.work_in_progress?
        SystemNoteService.handle_merge_request_wip(issuable, issuable.project, current_user)
      end
    end

    def create_labels_note(old_labels)
      added_labels = issuable.labels - old_labels
      removed_labels = old_labels - issuable.labels

      ResourceEvents::ChangeLabelsService
        .new(issuable, current_user)
        .execute(added_labels: added_labels, removed_labels: removed_labels)
    end

    def create_title_change_note(old_title)
      create_wip_note(old_title)

      if issuable.wipless_title_changed(old_title)
        SystemNoteService.change_title(issuable, issuable.project, current_user, old_title)
      end
    end

    def create_description_change_note
      SystemNoteService.change_description(issuable, issuable.project, current_user)
    end

    def create_task_status_note
      issuable.updated_tasks.each do |task|
        SystemNoteService.change_task_status(issuable, issuable.project, current_user, task)
      end
    end

    def create_time_estimate_note
      SystemNoteService.change_time_estimate(issuable, issuable.project, current_user)
    end

    def create_time_spent_note
      SystemNoteService.change_time_spent(issuable, issuable.project, issuable.time_spent_user)
    end

    def create_milestone_note
      SystemNoteService.change_milestone(issuable, issuable.project, current_user, issuable.milestone)
    end

    def create_due_date_note
      SystemNoteService.change_due_date(issuable, issuable.project, current_user, issuable.due_date)
    end

    def create_discussion_lock_note
      SystemNoteService.discussion_lock(issuable, current_user)
    end
  end
end

Issuable::CommonSystemNotesService.prepend_if_ee('EE::Issuable::CommonSystemNotesService')
