# frozen_string_literal: true

module SystemNotes
  class MergeRequestsService < ::SystemNotes::BaseService
    # Called when 'merge when pipeline succeeds' is executed
    def merge_when_pipeline_succeeds(sha)
      body = "enabled an automatic merge when the pipeline for #{sha} succeeds"

      create_note(NoteSummary.new(noteable, project, author, body, action: 'merge'))
    end

    # Called when 'merge when pipeline succeeds' is canceled
    def cancel_merge_when_pipeline_succeeds
      body = 'canceled the automatic merge'

      create_note(NoteSummary.new(noteable, project, author, body, action: 'merge'))
    end

    # Called when 'merge when pipeline succeeds' is aborted
    def abort_merge_when_pipeline_succeeds(reason)
      body = "aborted the automatic merge because #{reason}"

      ##
      # TODO: Abort message should be sent by the system, not a particular user.
      # See https://gitlab.com/gitlab-org/gitlab-foss/issues/63187.
      create_note(NoteSummary.new(noteable, project, author, body, action: 'merge'))
    end

    def handle_merge_request_wip
      prefix = noteable.work_in_progress? ? "marked" : "unmarked"

      body = "#{prefix} as a **Work In Progress**"

      create_note(NoteSummary.new(noteable, project, author, body, action: 'title'))
    end

    def add_merge_request_wip_from_commit(commit)
      body = "marked as a **Work In Progress** from #{commit.to_reference(project)}"

      create_note(NoteSummary.new(noteable, project, author, body, action: 'title'))
    end

    def resolve_all_discussions
      body = "resolved all threads"

      create_note(NoteSummary.new(noteable, project, author, body, action: 'discussion'))
    end

    def discussion_continued_in_issue(discussion, issue)
      body = "created #{issue.to_reference} to continue this discussion"
      note_attributes = discussion.reply_attributes.merge(project: project, author: author, note: body)

      Note.create(note_attributes.merge(system: true, created_at: issue.system_note_timestamp)).tap do |note|
        note.system_note_metadata = SystemNoteMetadata.new(action: 'discussion')
      end
    end

    def diff_discussion_outdated(discussion, change_position)
      merge_request = discussion.noteable
      diff_refs = change_position.diff_refs
      version_index = merge_request.merge_request_diffs.viewable.count
      position_on_text = change_position.on_text?
      text_parts = ["changed this #{position_on_text ? 'line' : 'file'} in"]

      if version_params = merge_request.version_params_for(diff_refs)
        repository = project.repository
        anchor = position_on_text ? change_position.line_code(repository) : change_position.file_hash
        url = url_helpers.diffs_project_merge_request_path(project, merge_request, version_params.merge(anchor: anchor))

        text_parts << "[version #{version_index} of the diff](#{url})"
      else
        text_parts << "version #{version_index} of the diff"
      end

      body = text_parts.join(' ')
      note_attributes = discussion.reply_attributes.merge(project: project, author: author, note: body)

      Note.create(note_attributes.merge(system: true)).tap do |note|
        note.system_note_metadata = SystemNoteMetadata.new(action: 'outdated')
      end
    end

    # Called when a branch in Noteable is changed
    #
    # branch_type - 'source' or 'target'
    # old_branch  - old branch name
    # new_branch  - new branch name
    #
    # Example Note text:
    #
    #   "changed target branch from `Old` to `New`"
    #
    # Returns the created Note object
    def change_branch(branch_type, old_branch, new_branch)
      body = "changed #{branch_type} branch from `#{old_branch}` to `#{new_branch}`"

      create_note(NoteSummary.new(noteable, project, author, body, action: 'branch'))
    end

    # Called when a branch in Noteable is added or deleted
    #
    # branch_type - :source or :target
    # branch      - branch name
    # presence    - :add or :delete
    #
    # Example Note text:
    #
    #   "restored target branch `feature`"
    #
    # Returns the created Note object
    def change_branch_presence(branch_type, branch, presence)
      verb =
        if presence == :add
          'restored'
        else
          'deleted'
        end

      body = "#{verb} #{branch_type} branch `#{branch}`"

      create_note(NoteSummary.new(noteable, project, author, body, action: 'branch'))
    end

    # Called when a branch is created from the 'new branch' button on a issue
    # Example note text:
    #
    #   "created branch `201-issue-branch-button`"
    def new_issue_branch(branch, branch_project: nil)
      branch_project ||= project
      link = url_helpers.project_compare_path(branch_project, from: branch_project.default_branch, to: branch)

      body = "created branch [`#{branch}`](#{link}) to address this issue"

      create_note(NoteSummary.new(noteable, project, author, body, action: 'branch'))
    end

    def new_merge_request(merge_request)
      body = "created merge request #{merge_request.to_reference(project)} to address this issue"

      create_note(NoteSummary.new(noteable, project, author, body, action: 'merge'))
    end
  end
end

SystemNotes::MergeRequestsService.prepend_if_ee('::EE::SystemNotes::MergeRequestsService')
