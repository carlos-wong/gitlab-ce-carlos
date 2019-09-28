# frozen_string_literal: true

module QA
  module Page
    module Project
      module Settings
        class ProtectedBranches < Page::Base
          view 'app/views/projects/protected_branches/shared/_dropdown.html.haml' do
            element :protected_branch_select
            element :protected_branch_dropdown
          end

          view 'app/views/projects/protected_branches/_create_protected_branch.html.haml' do
            element :allowed_to_push_select
            element :allowed_to_push_dropdown
            element :allowed_to_merge_select
            element :allowed_to_merge_dropdown
          end

          view 'app/views/projects/protected_branches/_update_protected_branch.html.haml' do
            element :allowed_to_merge
          end

          view 'app/views/projects/protected_branches/shared/_branches_list.html.haml' do
            element :protected_branches_list
          end

          view 'app/views/projects/protected_branches/shared/_create_protected_branch.html.haml' do
            element :protect_button
          end

          def select_branch(branch_name)
            click_element :protected_branch_select

            within_element(:protected_branch_dropdown) do
              click_on branch_name
            end
          end

          def select_allowed_to_merge(allowed)
            select_allowed(:merge, allowed)
          end

          def select_allowed_to_push(allowed)
            select_allowed(:push, allowed)
          end

          def protect_branch
            click_element :protect_button
          end

          private

          def select_allowed(action, allowed)
            click_element :"allowed_to_#{action}_select"

            allowed[:roles] = Resource::ProtectedBranch::Roles::NO_ONE unless allowed.key?(:roles)

            within_element(:"allowed_to_#{action}_dropdown") do
              click_on allowed[:roles]
            end

            # Click the select element again to close the dropdown
            click_element :protected_branch_select
          end
        end
      end
    end
  end
end

QA::Page::Project::Settings::ProtectedBranches.prepend_if_ee('QA::EE::Page::Project::Settings::ProtectedBranches')
