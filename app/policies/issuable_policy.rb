# frozen_string_literal: true

class IssuablePolicy < BasePolicy
  delegate { @subject.project }

  condition(:locked, scope: :subject, score: 0) { @subject.discussion_locked? }
  condition(:is_project_member) { @user && @subject.project && @subject.project.team.member?(@user) }

  desc "User is the assignee or author"
  condition(:assignee_or_author) do
    @user && @subject.assignee_or_author?(@user)
  end

  condition(:is_author) { @subject&.author == @user }

  condition(:is_incident) { @subject.incident? }

  rule { can?(:guest_access) & assignee_or_author & ~is_incident }.policy do
    enable :read_issue
    enable :update_issue
    enable :reopen_issue
  end

  # This rule replicates permissions in NotePolicy#can_read_confidential and it's used in
  # TodoPolicy for performance reasons
  rule { can?(:reporter_access) | assignee_or_author | admin }.policy do
    enable :read_confidential_notes
  end

  rule { can?(:read_merge_request) & assignee_or_author }.policy do
    enable :update_merge_request
    enable :reopen_merge_request
  end

  rule { is_author }.policy do
    enable :resolve_note
  end

  rule { locked & ~is_project_member }.policy do
    prevent :create_note
    prevent :admin_note
    prevent :resolve_note
    prevent :award_emoji
  end

  rule { can?(:read_issue) }.policy do
    enable :read_incident_management_timeline_event
  end

  rule { can?(:read_issue) & can?(:developer_access) }.policy do
    enable :admin_incident_management_timeline_event
  end

  rule { can?(:reporter_access) }.policy do
    enable :create_timelog
  end
end

IssuablePolicy.prepend_mod_with('IssuablePolicy')
