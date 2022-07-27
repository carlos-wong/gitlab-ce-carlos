# frozen_string_literal: true

module Namespaces
  class UserNamespacePolicy < ::NamespacePolicy
    rule { anonymous }.prevent_all

    condition(:can_create_personal_project, scope: :user) { @user.can_create_project? }
    condition(:owner) { @subject.owner == @user }

    rule { owner | admin }.policy do
      enable :owner_access
      enable :create_projects
      enable :admin_namespace
      enable :maintain_namespace
      enable :read_namespace
      enable :read_statistics
      enable :create_jira_connect_subscription
      enable :admin_package
    end

    rule { ~can_create_personal_project }.prevent :create_projects

    rule { (owner | admin) & can?(:create_projects) }.enable :transfer_projects
  end
end

Namespaces::UserNamespacePolicy.prepend_mod_with('Namespaces::UserNamespacePolicy')
