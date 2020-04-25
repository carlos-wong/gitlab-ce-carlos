# frozen_string_literal: true

module QA
  module Page
    module Project
      class Show < Page::Base
        include Page::Component::ClonePanel
        include Page::Project::SubMenus::Settings

        view 'app/assets/javascripts/repository/components/table/row.vue' do
          element :file_name_link
        end

        view 'app/assets/javascripts/repository/components/table/index.vue' do
          element :file_tree_table
        end

        view 'app/views/layouts/header/_new_dropdown.haml' do
          element :new_menu_toggle
          element :new_issue_link, "link_to _('New issue'), new_project_issue_path(@project)" # rubocop:disable QA/ElementWithPattern
        end

        view 'app/views/projects/_last_push.html.haml' do
          element :create_merge_request
        end

        view 'app/views/projects/_home_panel.html.haml' do
          element :forked_from_link
          element :project_name_content
        end

        view 'app/views/projects/_files.html.haml' do
          element :tree_holder, '.tree-holder' # rubocop:disable QA/ElementWithPattern
        end

        view 'app/views/projects/buttons/_dropdown.html.haml' do
          element :create_new_dropdown
        end

        view 'app/views/projects/buttons/_fork.html.haml' do
          element :fork_label, "%span= s_('ProjectOverview|Fork')" # rubocop:disable QA/ElementWithPattern
          element :fork_link, "link_to new_project_fork_path(@project)" # rubocop:disable QA/ElementWithPattern
        end

        view 'app/views/projects/empty.html.haml' do
          element :quick_actions
        end

        view 'app/views/projects/tree/_tree_header.html.haml' do
          element :add_to_tree
          element :new_file_option
          element :web_ide_button
        end

        view 'app/views/shared/_ref_switcher.html.haml' do
          element :branches_select
          element :branches_dropdown
        end

        view 'app/views/projects/blob/viewers/_loading.html.haml' do
          element :spinner
        end

        view 'app/views/projects/buttons/_download.html.haml' do
          element :download_source_code_button
        end

        def wait_for_viewers_to_load
          has_no_element?(:spinner, wait: QA::Support::Repeater::DEFAULT_MAX_WAIT_TIME)
        end

        def create_first_new_file!
          within_element(:quick_actions) do
            click_link_with_text 'New file'
          end
        end

        def create_new_file!
          click_element :add_to_tree
          click_element :new_file_option
        end

        def fork_project
          click_on 'Fork'
        end

        def forked_from?(parent_project_name)
          has_element?(:forked_from_link, text: parent_project_name)
        end

        def click_file(filename)
          within_element(:file_tree_table) do
            click_on filename
          end
        end

        def click_commit(commit_msg)
          within_element(:file_tree_table) do
            click_on commit_msg
          end
        end

        def go_to_new_issue
          click_element :new_menu_toggle
          click_link 'New issue'
        end

        def has_file?(name)
          within_element(:file_tree_table) do
            has_element?(:file_name_link, text: name)
          end
        end

        def has_name?(name)
          has_element?(:project_name_content, text: name)
        end

        def last_commit_content
          find_element(:commit_content).text
        end

        def new_merge_request
          wait_until(reload: true) do
            has_css?(element_selector_css(:create_merge_request))
          end

          click_element :create_merge_request
        end

        def open_web_ide!
          click_element :web_ide_button
        end

        def project_name
          find_element(:project_name_content).text
        end

        def switch_to_branch(branch_name)
          find_element(:branches_select).click

          within_element(:branches_dropdown) do
            click_on branch_name
          end
        end

        def wait_for_import
          wait_until(reload: true) do
            has_css?('.tree-holder')
          end
        end
      end
    end
  end
end

QA::Page::Project::Show.prepend_if_ee('QA::EE::Page::Project::Show')
