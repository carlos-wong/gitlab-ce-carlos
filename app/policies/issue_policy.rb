# frozen_string_literal: true

class IssuePolicy < IssuablePolicy
  # This class duplicates the same check of Issue#readable_by? for performance reasons
  # Make sure to sync this class checks with issue.rb to avoid security problems.
  # Check commit 002ad215818450d2cbbc5fa065850a953dc7ada8 for more information.

  include CrudPolicyHelpers

  desc "User can read confidential issues"
  condition(:can_read_confidential) do
    @user && IssueCollection.new([@subject]).visible_to(@user).any?
  end

  desc "Project belongs to a group, crm is enabled and user can read contacts in the root group"
  condition(:can_read_crm_contacts, scope: :subject) do
    subject.project.group&.crm_enabled? &&
      (@user&.can?(:read_crm_contact, @subject.project.root_ancestor) || @user&.support_bot?)
  end

  desc "Issue is confidential"
  condition(:confidential, scope: :subject) { @subject.confidential? }

  desc "Issue is hidden"
  condition(:hidden, scope: :subject) { @subject.hidden? }

  desc "Issue is persisted"
  condition(:persisted, scope: :subject) { @subject.persisted? }

  rule { confidential & ~can_read_confidential }.policy do
    prevent(*create_read_update_admin_destroy(:issue))
    prevent :read_issue_iid
  end

  rule { hidden & ~admin }.policy do
    prevent :read_issue
  end

  rule { ~can?(:read_issue) }.prevent :create_note

  rule { locked }.policy do
    prevent :reopen_issue
  end

  rule { ~can?(:read_issue) }.policy do
    prevent :read_design
    prevent :create_design
    prevent :destroy_design
  end

  rule { ~can?(:read_design) }.policy do
    prevent :move_design
  end

  rule { ~anonymous & can?(:read_issue) }.policy do
    enable :create_todo
    enable :update_subscription
  end

  rule { can?(:admin_issue) }.policy do
    enable :set_issue_metadata
  end

  # guest members need to be able to set issue metadata per https://gitlab.com/gitlab-org/gitlab/-/issues/300100
  rule { ~persisted & is_project_member & can?(:guest_access) }.policy do
    enable :set_issue_metadata
  end

  rule { can?(:set_issue_metadata) }.policy do
    enable :set_confidentiality
  end

  rule { ~persisted & can?(:create_issue) }.policy do
    enable :set_confidentiality
  end

  rule { can_read_crm_contacts }.policy do
    enable :read_crm_contacts
  end

  rule { can?(:set_issue_metadata) & can_read_crm_contacts }.policy do
    enable :set_issue_crm_contacts
  end
end

IssuePolicy.prepend_mod_with('IssuePolicy')
