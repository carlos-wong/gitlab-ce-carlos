# frozen_string_literal: true

# SystemNoteService
#
# Used for creating system notes (e.g., when a user references a merge request
# from an issue, an issue's assignee changes, an issue is closed, etc.)
module SystemNoteService
  extend self

  # Called when commits are added to a Merge Request
  #
  # noteable         - Noteable object
  # project          - Project owning noteable
  # author           - User performing the change
  # new_commits      - Array of Commits added since last push
  # existing_commits - Array of Commits added in a previous push
  # oldrev           - Optional String SHA of a previous Commit
  #
  # See new_commit_summary and existing_commit_summary.
  #
  # Returns the created Note object
  def add_commits(noteable, project, author, new_commits, existing_commits = [], oldrev = nil)
    total_count  = new_commits.length + existing_commits.length
    commits_text = "#{total_count} commit".pluralize(total_count)

    text_parts = ["added #{commits_text}"]
    text_parts << commits_list(noteable, new_commits, existing_commits, oldrev)
    text_parts << "[Compare with previous version](#{diff_comparison_path(noteable, project, oldrev)})"

    body = text_parts.join("\n\n")

    create_note(NoteSummary.new(noteable, project, author, body, action: 'commit', commit_count: total_count))
  end

  # Called when a commit was tagged
  #
  # noteable  - Noteable object
  # project   - Project owning noteable
  # author    - User performing the tag
  # tag_name  - The created tag name
  #
  # Returns the created Note object
  def tag_commit(noteable, project, author, tag_name)
    link = url_helpers.project_tag_path(project, id: tag_name)
    body = "tagged commit #{noteable.sha} to [`#{tag_name}`](#{link})"

    create_note(NoteSummary.new(noteable, project, author, body, action: 'tag'))
  end

  # Called when the assignee of a Noteable is changed or removed
  #
  # noteable - Noteable object
  # project  - Project owning noteable
  # author   - User performing the change
  # assignee - User being assigned, or nil
  #
  # Example Note text:
  #
  #   "removed assignee"
  #
  #   "assigned to @rspeicher"
  #
  # Returns the created Note object
  def change_assignee(noteable, project, author, assignee)
    body = assignee.nil? ? 'removed assignee' : "assigned to #{assignee.to_reference}"

    create_note(NoteSummary.new(noteable, project, author, body, action: 'assignee'))
  end

  # Called when the assignees of an Issue is changed or removed
  #
  # issuable - Issuable object (responds to assignees)
  # project  - Project owning noteable
  # author   - User performing the change
  # assignees - Users being assigned, or nil
  #
  # Example Note text:
  #
  #   "removed all assignees"
  #
  #   "assigned to @user1 additionally to @user2"
  #
  #   "assigned to @user1, @user2 and @user3 and unassigned from @user4 and @user5"
  #
  #   "assigned to @user1 and @user2"
  #
  # Returns the created Note object
  def change_issuable_assignees(issuable, project, author, old_assignees)
    unassigned_users = old_assignees - issuable.assignees
    added_users = issuable.assignees.to_a - old_assignees

    text_parts = []
    text_parts << "assigned to #{added_users.map(&:to_reference).to_sentence}" if added_users.any?
    text_parts << "unassigned #{unassigned_users.map(&:to_reference).to_sentence}" if unassigned_users.any?

    body = text_parts.join(' and ')

    create_note(NoteSummary.new(issuable, project, author, body, action: 'assignee'))
  end

  # Called when the milestone of a Noteable is changed
  #
  # noteable  - Noteable object
  # project   - Project owning noteable
  # author    - User performing the change
  # milestone - Milestone being assigned, or nil
  #
  # Example Note text:
  #
  #   "removed milestone"
  #
  #   "changed milestone to 7.11"
  #
  # Returns the created Note object
  def change_milestone(noteable, project, author, milestone)
    format = milestone&.group_milestone? ? :name : :iid
    body = milestone.nil? ? 'removed milestone' : "changed milestone to #{milestone.to_reference(project, format: format)}"

    create_note(NoteSummary.new(noteable, project, author, body, action: 'milestone'))
  end

  # Called when the due_date of a Noteable is changed
  #
  # noteable  - Noteable object
  # project   - Project owning noteable
  # author    - User performing the change
  # due_date  - Due date being assigned, or nil
  #
  # Example Note text:
  #
  #   "removed due date"
  #
  #   "changed due date to September 20, 2018"
  #
  # Returns the created Note object
  def change_due_date(noteable, project, author, due_date)
    body = due_date ? "changed due date to #{due_date.to_s(:long)}" : 'removed due date'

    create_note(NoteSummary.new(noteable, project, author, body, action: 'due_date'))
  end

  # Called when the estimated time of a Noteable is changed
  #
  # noteable      - Noteable object
  # project       - Project owning noteable
  # author        - User performing the change
  # time_estimate - Estimated time
  #
  # Example Note text:
  #
  #   "removed time estimate"
  #
  #   "changed time estimate to 3d 5h"
  #
  # Returns the created Note object
  def change_time_estimate(noteable, project, author)
    parsed_time = Gitlab::TimeTrackingFormatter.output(noteable.time_estimate)
    body = if noteable.time_estimate == 0
             "removed time estimate"
           else
             "changed time estimate to #{parsed_time}"
           end

    create_note(NoteSummary.new(noteable, project, author, body, action: 'time_tracking'))
  end

  # Called when the spent time of a Noteable is changed
  #
  # noteable   - Noteable object
  # project    - Project owning noteable
  # author     - User performing the change
  # time_spent - Spent time
  #
  # Example Note text:
  #
  #   "removed time spent"
  #
  #   "added 2h 30m of time spent"
  #
  # Returns the created Note object
  def change_time_spent(noteable, project, author)
    time_spent = noteable.time_spent

    if time_spent == :reset
      body = "removed time spent"
    else
      spent_at = noteable.spent_at
      parsed_time = Gitlab::TimeTrackingFormatter.output(time_spent.abs)
      action = time_spent > 0 ? 'added' : 'subtracted'

      text_parts = ["#{action} #{parsed_time} of time spent"]
      text_parts << "at #{spent_at}" if spent_at
      body = text_parts.join(' ')
    end

    create_note(NoteSummary.new(noteable, project, author, body, action: 'time_tracking'))
  end

  # Called when the status of a Noteable is changed
  #
  # noteable - Noteable object
  # project  - Project owning noteable
  # author   - User performing the change
  # status   - String status
  # source   - Mentionable performing the change, or nil
  #
  # Example Note text:
  #
  #   "merged"
  #
  #   "closed via bc17db76"
  #
  # Returns the created Note object
  def change_status(noteable, project, author, status, source = nil)
    body = status.dup
    body << " via #{source.gfm_reference(project)}" if source

    action = status == 'reopened' ? 'opened' : status

    create_note(NoteSummary.new(noteable, project, author, body, action: action))
  end

  # Called when 'merge when pipeline succeeds' is executed
  def merge_when_pipeline_succeeds(noteable, project, author, last_commit)
    body = "enabled an automatic merge when the pipeline for #{last_commit.to_reference(project)} succeeds"

    create_note(NoteSummary.new(noteable, project, author, body, action: 'merge'))
  end

  # Called when 'merge when pipeline succeeds' is canceled
  def cancel_merge_when_pipeline_succeeds(noteable, project, author)
    body = 'canceled the automatic merge'

    create_note(NoteSummary.new(noteable, project, author, body, action: 'merge'))
  end

  def handle_merge_request_wip(noteable, project, author)
    prefix = noteable.work_in_progress? ? "marked" : "unmarked"

    body = "#{prefix} as a **Work In Progress**"

    create_note(NoteSummary.new(noteable, project, author, body, action: 'title'))
  end

  def add_merge_request_wip_from_commit(noteable, project, author, commit)
    body = "marked as a **Work In Progress** from #{commit.to_reference(project)}"

    create_note(NoteSummary.new(noteable, project, author, body, action: 'title'))
  end

  def resolve_all_discussions(merge_request, project, author)
    body = "resolved all discussions"

    create_note(NoteSummary.new(merge_request, project, author, body, action: 'discussion'))
  end

  def discussion_continued_in_issue(discussion, project, author, issue)
    body = "created #{issue.to_reference} to continue this discussion"
    note_attributes = discussion.reply_attributes.merge(project: project, author: author, note: body)

    note = Note.create(note_attributes.merge(system: true, created_at: issue.system_note_timestamp))
    note.system_note_metadata = SystemNoteMetadata.new(action: 'discussion')

    note
  end

  def diff_discussion_outdated(discussion, project, author, change_position)
    merge_request = discussion.noteable
    diff_refs = change_position.diff_refs
    version_index = merge_request.merge_request_diffs.viewable.count

    text_parts = ["changed this line in"]
    if version_params = merge_request.version_params_for(diff_refs)
      line_code = change_position.line_code(project.repository)
      url = url_helpers.diffs_project_merge_request_path(project, merge_request, version_params.merge(anchor: line_code))

      text_parts << "[version #{version_index} of the diff](#{url})"
    else
      text_parts << "version #{version_index} of the diff"
    end

    body = text_parts.join(' ')
    note_attributes = discussion.reply_attributes.merge(project: project, author: author, note: body)

    note = Note.create(note_attributes.merge(system: true))
    note.system_note_metadata = SystemNoteMetadata.new(action: 'outdated')

    note
  end

  # Called when the title of a Noteable is changed
  #
  # noteable  - Noteable object that responds to `title`
  # project   - Project owning noteable
  # author    - User performing the change
  # old_title - Previous String title
  #
  # Example Note text:
  #
  #   "changed title from **Old** to **New**"
  #
  # Returns the created Note object
  def change_title(noteable, project, author, old_title)
    new_title = noteable.title.dup

    old_diffs, new_diffs = Gitlab::Diff::InlineDiff.new(old_title, new_title).inline_diffs

    marked_old_title = Gitlab::Diff::InlineDiffMarkdownMarker.new(old_title).mark(old_diffs, mode: :deletion)
    marked_new_title = Gitlab::Diff::InlineDiffMarkdownMarker.new(new_title).mark(new_diffs, mode: :addition)

    body = "changed title from **#{marked_old_title}** to **#{marked_new_title}**"

    create_note(NoteSummary.new(noteable, project, author, body, action: 'title'))
  end

  # Called when the description of a Noteable is changed
  #
  # noteable  - Noteable object that responds to `description`
  # project   - Project owning noteable
  # author    - User performing the change
  #
  # Example Note text:
  #
  #   "changed the description"
  #
  # Returns the created Note object
  def change_description(noteable, project, author)
    body = 'changed the description'

    create_note(NoteSummary.new(noteable, project, author, body, action: 'description'))
  end

  # Called when the confidentiality changes
  #
  # issue   - Issue object
  # project - Project owning the issue
  # author  - User performing the change
  #
  # Example Note text:
  #
  #   "made the issue confidential"
  #
  # Returns the created Note object
  def change_issue_confidentiality(issue, project, author)
    if issue.confidential
      body = 'made the issue confidential'
      action = 'confidential'
    else
      body = 'made the issue visible to everyone'
      action = 'visible'
    end

    create_note(NoteSummary.new(issue, project, author, body, action: action))
  end

  # Called when a branch in Noteable is changed
  #
  # noteable    - Noteable object
  # project     - Project owning noteable
  # author      - User performing the change
  # branch_type - 'source' or 'target'
  # old_branch  - old branch name
  # new_branch  - new branch name
  #
  # Example Note text:
  #
  #   "changed target branch from `Old` to `New`"
  #
  # Returns the created Note object
  def change_branch(noteable, project, author, branch_type, old_branch, new_branch)
    body = "changed #{branch_type} branch from `#{old_branch}` to `#{new_branch}`"

    create_note(NoteSummary.new(noteable, project, author, body, action: 'branch'))
  end

  # Called when a branch in Noteable is added or deleted
  #
  # noteable    - Noteable object
  # project     - Project owning noteable
  # author      - User performing the change
  # branch_type - :source or :target
  # branch      - branch name
  # presence    - :add or :delete
  #
  # Example Note text:
  #
  #   "restored target branch `feature`"
  #
  # Returns the created Note object
  def change_branch_presence(noteable, project, author, branch_type, branch, presence)
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
  def new_issue_branch(issue, project, author, branch)
    link = url_helpers.project_compare_path(project, from: project.default_branch, to: branch)

    body = "created branch [`#{branch}`](#{link}) to address this issue"

    create_note(NoteSummary.new(issue, project, author, body, action: 'branch'))
  end

  def new_merge_request(issue, project, author, merge_request)
    body = "created merge request #{merge_request.to_reference} to address this issue"

    create_note(NoteSummary.new(issue, project, author, body, action: 'merge'))
  end

  # Called when a Mentionable references a Noteable
  #
  # noteable  - Noteable object being referenced
  # mentioner - Mentionable object
  # author    - User performing the reference
  #
  # Example Note text:
  #
  #   "mentioned in #1"
  #
  #   "mentioned in !2"
  #
  #   "mentioned in 54f7727c"
  #
  # See cross_reference_note_content.
  #
  # Returns the created Note object
  def cross_reference(noteable, mentioner, author)
    return if cross_reference_disallowed?(noteable, mentioner)

    gfm_reference = mentioner.gfm_reference(noteable.project || noteable.group)
    body = cross_reference_note_content(gfm_reference)

    if noteable.is_a?(ExternalIssue)
      noteable.project.issues_tracker.create_cross_reference_note(noteable, mentioner, author)
    else
      create_note(NoteSummary.new(noteable, noteable.project, author, body, action: 'cross_reference'))
    end
  end

  # Check if a cross-reference is disallowed
  #
  # This method prevents adding a "mentioned in !1" note on every single commit
  # in a merge request. Additionally, it prevents the creation of references to
  # external issues (which would fail).
  #
  # noteable  - Noteable object being referenced
  # mentioner - Mentionable object
  #
  # Returns Boolean
  def cross_reference_disallowed?(noteable, mentioner)
    return true if noteable.is_a?(ExternalIssue) && !noteable.project.jira_tracker_active?
    return false unless mentioner.is_a?(MergeRequest)
    return false unless noteable.is_a?(Commit)

    mentioner.commits.include?(noteable)
  end

  # Check if a cross reference to a noteable from a mentioner already exists
  #
  # This method is used to prevent multiple notes being created for a mention
  # when a issue is updated, for example. The method also calls notes_for_mentioner
  # to check if the mentioner is a commit, and return matches only on commit hash
  # instead of project + commit, to avoid repeated mentions from forks.
  #
  # noteable  - Noteable object being referenced
  # mentioner - Mentionable object
  #
  # Returns Boolean
  def cross_reference_exists?(noteable, mentioner)
    notes = noteable.notes.system
    notes_for_mentioner(mentioner, noteable, notes).exists?
  end

  # Build an Array of lines detailing each commit added in a merge request
  #
  # new_commits - Array of new Commit objects
  #
  # Returns an Array of Strings
  def new_commit_summary(new_commits)
    new_commits.collect do |commit|
      content_tag('li', "#{commit.short_id} - #{commit.title}")
    end
  end

  # Called when the status of a Task has changed
  #
  # noteable  - Noteable object.
  # project   - Project owning noteable
  # author    - User performing the change
  # new_task  - TaskList::Item object.
  #
  # Example Note text:
  #
  #   "marked the task Whatever as completed."
  #
  # Returns the created Note object
  def change_task_status(noteable, project, author, new_task)
    status_label = new_task.complete? ? Taskable::COMPLETED : Taskable::INCOMPLETE
    body = "marked the task **#{new_task.source}** as #{status_label}"

    create_note(NoteSummary.new(noteable, project, author, body, action: 'task'))
  end

  # Called when noteable has been moved to another project
  #
  # direction    - symbol, :to or :from
  # noteable     - Noteable object
  # noteable_ref - Referenced noteable
  # author       - User performing the move
  #
  # Example Note text:
  #
  #   "moved to some_namespace/project_new#11"
  #
  # Returns the created Note object
  def noteable_moved(noteable, project, noteable_ref, author, direction:)
    unless [:to, :from].include?(direction)
      raise ArgumentError, "Invalid direction `#{direction}`"
    end

    cross_reference = noteable_ref.to_reference(project)
    body = "moved #{direction} #{cross_reference}"

    create_note(NoteSummary.new(noteable, project, author, body, action: 'moved'))
  end

  # Called when a Noteable has been marked as a duplicate of another Issue
  #
  # noteable        - Noteable object
  # project         - Project owning noteable
  # author          - User performing the change
  # canonical_issue - Issue that this is a duplicate of
  #
  # Example Note text:
  #
  #   "marked this issue as a duplicate of #1234"
  #
  #   "marked this issue as a duplicate of other_project#5678"
  #
  # Returns the created Note object
  def mark_duplicate_issue(noteable, project, author, canonical_issue)
    body = "marked this issue as a duplicate of #{canonical_issue.to_reference(project)}"
    create_note(NoteSummary.new(noteable, project, author, body, action: 'duplicate'))
  end

  # Called when a Noteable has been marked as the canonical Issue of a duplicate
  #
  # noteable        - Noteable object
  # project         - Project owning noteable
  # author          - User performing the change
  # duplicate_issue - Issue that was a duplicate of this
  #
  # Example Note text:
  #
  #   "marked #1234 as a duplicate of this issue"
  #
  #   "marked other_project#5678 as a duplicate of this issue"
  #
  # Returns the created Note object
  def mark_canonical_issue_of_duplicate(noteable, project, author, duplicate_issue)
    body = "marked #{duplicate_issue.to_reference(project)} as a duplicate of this issue"
    create_note(NoteSummary.new(noteable, project, author, body, action: 'duplicate'))
  end

  def discussion_lock(issuable, author)
    action = issuable.discussion_locked? ? 'locked' : 'unlocked'
    body = "#{action} this #{issuable.class.to_s.titleize.downcase}"

    create_note(NoteSummary.new(issuable, issuable.project, author, body, action: action))
  end

  def cross_reference?(note_text)
    note_text =~ /\A#{cross_reference_note_prefix}/i
  end

  private

  # rubocop: disable CodeReuse/ActiveRecord
  def notes_for_mentioner(mentioner, noteable, notes)
    if mentioner.is_a?(Commit)
      text = "#{cross_reference_note_prefix}%#{mentioner.to_reference(nil)}"
      notes.where('(note LIKE ? OR note LIKE ?)', text, text.capitalize)
    else
      gfm_reference = mentioner.gfm_reference(noteable.project || noteable.group)
      text = cross_reference_note_content(gfm_reference)
      notes.where(note: [text, text.capitalize])
    end
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def create_note(note_summary)
    note = Note.create(note_summary.note.merge(system: true))
    note.system_note_metadata = SystemNoteMetadata.new(note_summary.metadata) if note_summary.metadata?

    note
  end

  def cross_reference_note_prefix
    'mentioned in '
  end

  def cross_reference_note_content(gfm_reference)
    "#{cross_reference_note_prefix}#{gfm_reference}"
  end

  # Builds a list of existing and new commits according to existing_commits and
  # new_commits methods.
  # Returns a String wrapped in `ul` and `li` tags.
  def commits_list(noteable, new_commits, existing_commits, oldrev)
    existing_commit_summary = existing_commit_summary(noteable, existing_commits, oldrev)
    new_commit_summary = new_commit_summary(new_commits).join

    content_tag('ul', "#{existing_commit_summary}#{new_commit_summary}".html_safe)
  end

  # Build a single line summarizing existing commits being added in a merge
  # request
  #
  # noteable         - MergeRequest object
  # existing_commits - Array of existing Commit objects
  # oldrev           - Optional String SHA of a previous Commit
  #
  # Examples:
  #
  #   "* ea0f8418...2f4426b7 - 24 commits from branch `master`"
  #
  #   "* ea0f8418..4188f0ea - 15 commits from branch `fork:master`"
  #
  #   "* ea0f8418 - 1 commit from branch `feature`"
  #
  # Returns a newline-terminated String
  def existing_commit_summary(noteable, existing_commits, oldrev = nil)
    return '' if existing_commits.empty?

    count = existing_commits.size

    commit_ids = if count == 1
                   existing_commits.first.short_id
                 else
                   if oldrev && !Gitlab::Git.blank_ref?(oldrev)
                     "#{Commit.truncate_sha(oldrev)}...#{existing_commits.last.short_id}"
                   else
                     "#{existing_commits.first.short_id}..#{existing_commits.last.short_id}"
                   end
                 end

    commits_text = "#{count} commit".pluralize(count)

    branch = noteable.target_branch
    branch = "#{noteable.target_project_namespace}:#{branch}" if noteable.for_fork?

    branch_name = content_tag('code', branch)
    content_tag('li', "#{commit_ids} - #{commits_text} from branch #{branch_name}".html_safe)
  end

  def url_helpers
    @url_helpers ||= Gitlab::Routing.url_helpers
  end

  def diff_comparison_path(merge_request, project, oldrev)
    diff_id = merge_request.merge_request_diff.id

    url_helpers.diffs_project_merge_request_path(
      project,
      merge_request,
      diff_id: diff_id,
      start_sha: oldrev
    )
  end

  def content_tag(*args)
    ActionController::Base.helpers.content_tag(*args)
  end
end
