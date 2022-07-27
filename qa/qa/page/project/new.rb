# frozen_string_literal: true

module QA
  module Page
    module Project
      class New < Page::Base
        include Page::Component::Project::Templates
        include Page::Component::VisibilitySetting

        include Layout::Flash
        include Page::Component::Import::Selection
        include Page::Component::Import::Gitlab

        view 'app/views/projects/_new_project_fields.html.haml' do
          element :initialize_with_readme_checkbox
          element :initialize_with_sast_checkbox
          element :project_name
          element :project_path
          element :project_description
          element :project_create_button
          element :visibility_radios
        end

        view 'app/views/projects/project_templates/_template.html.haml' do
          element :use_template_button
          element :template_option_row
        end

        view 'app/assets/javascripts/projects/new/components/new_project_url_select.vue' do
          element :select_namespace_dropdown
          element :select_namespace_dropdown_search_field
        end

        view 'app/assets/javascripts/vue_shared/new_namespace/components/welcome.vue' do
          element :panel_link
        end

        def click_blank_project_link
          click_element(:panel_link, panel_name: 'blank_project')
        end

        def click_create_from_template_link
          click_element(:panel_link, panel_name: 'create_from_template')
        end

        def choose_test_namespace
          choose_namespace(Runtime::Namespace.path)
        end

        def choose_namespace(namespace)
          retry_on_exception do
            click_element :select_namespace_dropdown
            fill_element :select_namespace_dropdown_search_field, namespace
            click_button namespace
          end
        end

        def click_import_project
          click_on 'Import project'
        end

        def choose_name(name)
          fill_in 'project_name', with: name
        end

        def add_description(description)
          fill_in 'project_description', with: description
        end

        def create_new_project
          click_on 'Create project'
        end

        def click_create_from_template_tab
          click_element(:project_create_from_template_tab)
        end

        def set_visibility(visibility)
          find('label', text: visibility.capitalize).click
        end

        # Disable experiment for SAST at project creation https://gitlab.com/gitlab-org/gitlab/-/issues/333196
        def disable_initialize_with_sast
          return unless has_element?(:initialize_with_sast_checkbox)

          uncheck_element(:initialize_with_sast_checkbox)
        end

        def click_github_link
          click_link 'GitHub'
        end

        def click_repo_by_url_link
          click_button 'Repository by URL'
        end

        def disable_initialize_with_readme
          uncheck_element(:initialize_with_readme_checkbox)
        end
      end
    end
  end
end

QA::Page::Project::New.prepend_mod_with('Page::Project::New', namespace: QA)
