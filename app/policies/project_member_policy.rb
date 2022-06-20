# frozen_string_literal: true

class ProjectMemberPolicy < BasePolicy
  delegate { @subject.project }

  condition(:target_is_holder_of_the_personal_namespace, scope: :subject) do
    @subject.project.personal_namespace_holder?(@subject.user)
  end

  condition(:target_is_self) { @user && @subject.user == @user }
  condition(:project_bot) { @subject.user&.project_bot? }

  rule { anonymous }.prevent_all

  rule { target_is_holder_of_the_personal_namespace }.policy do
    prevent :update_project_member
    prevent :destroy_project_member
  end

  rule { ~project_bot & can?(:admin_project_member) }.policy do
    enable :update_project_member
    enable :destroy_project_member
  end

  rule { project_bot & can?(:admin_project_member) }.enable :destroy_project_bot_member

  rule { target_is_self }.enable :destroy_project_member
end
