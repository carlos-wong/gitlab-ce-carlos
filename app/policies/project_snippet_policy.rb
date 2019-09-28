# frozen_string_literal: true

class ProjectSnippetPolicy < BasePolicy
  delegate :project

  desc "Snippet is public"
  condition(:public_snippet, scope: :subject) { @subject.public? }
  condition(:internal_snippet, scope: :subject) { @subject.internal? }
  condition(:private_snippet, scope: :subject) { @subject.private? }
  condition(:public_project, scope: :subject) { @subject.project.public? }

  condition(:is_author) { @user && @subject.author == @user }

  # We have to check both project feature visibility and a snippet visibility and take the stricter one
  # This will be simplified - check https://gitlab.com/gitlab-org/gitlab-foss/issues/27573
  rule { ~can?(:read_project) }.policy do
    prevent :read_project_snippet
    prevent :update_project_snippet
    prevent :admin_project_snippet
  end

  # we have to use this complicated prevent because the delegated project policy
  # is overly greedy in allowing :read_project_snippet, since it doesn't have any
  # information about the snippet. However, :read_project_snippet on the *project*
  # is used to hide/show various snippet-related controls, so we can't just move
  # all of the handling here.
  rule do
    all?(private_snippet | (internal_snippet & external_user),
         ~project.guest,
         ~is_author,
         ~full_private_access)
  end.prevent :read_project_snippet

  rule { internal_snippet & ~is_author & ~admin }.policy do
    prevent :update_project_snippet
    prevent :admin_project_snippet
  end

  rule { public_snippet }.enable :read_project_snippet

  rule { is_author | admin }.policy do
    enable :read_project_snippet
    enable :update_project_snippet
    enable :admin_project_snippet
  end

  rule { ~can?(:read_project_snippet) }.prevent :create_note
end

ProjectSnippetPolicy.prepend_if_ee('EE::ProjectSnippetPolicy')
