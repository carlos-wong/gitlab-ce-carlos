# frozen_string_literal: true

module Ci
  class BuildPolicy < CommitStatusPolicy
    condition(:protected_ref) do
      access = ::Gitlab::UserAccess.new(@user, project: @subject.project)

      if @subject.tag?
        !access.can_create_tag?(@subject.ref)
      else
        !access.can_update_branch?(@subject.ref)
      end
    end

    condition(:owner_of_job) do
      @subject.triggered_by?(@user)
    end

    condition(:branch_allows_collaboration) do
      @subject.project.branch_allows_collaboration?(@user, @subject.ref)
    end

    condition(:archived, scope: :subject) do
      @subject.archived?
    end

    condition(:terminal, scope: :subject) do
      @subject.has_terminal?
    end

    rule { protected_ref | archived }.policy do
      prevent :update_build
      prevent :update_commit_status
      prevent :erase_build
    end

    rule { can?(:admin_build) | (can?(:update_build) & owner_of_job) }.enable :erase_build

    rule { can?(:public_access) & branch_allows_collaboration }.policy do
      enable :update_build
      enable :update_commit_status
    end

    rule { can?(:update_build) & terminal }.enable :create_build_terminal
  end
end

Ci::BuildPolicy.prepend_if_ee('EE::Ci::BuildPolicy')
