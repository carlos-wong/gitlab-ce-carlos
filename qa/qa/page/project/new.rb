# frozen_string_literal: true

module QA
  module Page
    module Project
      class New < Page::Base
        include Page::Component::Select2

        view 'app/views/projects/new.html.haml' do
          element :project_create_from_template_tab
          element :import_project_tab, "Import project" # rubocop:disable QA/ElementWithPattern
        end

        view 'app/views/projects/_new_project_fields.html.haml' do
          element :initialize_with_readme_checkbox
          element :project_namespace_select
          element :project_namespace_field, 'namespaces_options' # rubocop:disable QA/ElementWithPattern
          element :project_name, 'text_field :name' # rubocop:disable QA/ElementWithPattern
          element :project_path, 'text_field :path' # rubocop:disable QA/ElementWithPattern
          element :project_description, 'text_area :description' # rubocop:disable QA/ElementWithPattern
          element :project_create_button, "submit 'Create project'" # rubocop:disable QA/ElementWithPattern
          element :visibility_radios, 'visibility_level:' # rubocop:disable QA/ElementWithPattern
        end

        view 'app/views/projects/_import_project_pane.html.haml' do
          element :import_github, "icon('github', text: 'GitHub')" # rubocop:disable QA/ElementWithPattern
        end

        def choose_test_namespace
          choose_namespace(Runtime::Namespace.path)
        end

        def choose_namespace(namespace)
          retry_on_exception do
            click_body
            click_element :project_namespace_select
            search_and_select(namespace)
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
          choose visibility
        end

        def click_github_link
          click_link 'GitHub'
        end

        def enable_initialize_with_readme
          check_element :initialize_with_readme_checkbox
        end
      end
    end
  end
end
