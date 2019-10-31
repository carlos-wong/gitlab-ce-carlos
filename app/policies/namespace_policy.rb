# frozen_string_literal: true

class NamespacePolicy < BasePolicy
  rule { anonymous }.prevent_all

  condition(:personal_project, scope: :subject) { @subject.kind == 'user' }
  condition(:can_create_personal_project, scope: :user) { @user.can_create_project? }
  condition(:owner) { @subject.owner == @user }

  rule { owner | admin }.policy do
    enable :create_projects
    enable :admin_namespace
    enable :read_namespace
    enable :read_statistics
  end

  rule { personal_project & ~can_create_personal_project }.prevent :create_projects

  rule { (owner | admin) & can?(:create_projects) }.enable :transfer_projects
end

NamespacePolicy.prepend_if_ee('EE::NamespacePolicy')
