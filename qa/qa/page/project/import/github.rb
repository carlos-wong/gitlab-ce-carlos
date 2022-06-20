# frozen_string_literal: true

module QA
  module Page
    module Project
      module Import
        class Github < Page::Base
          include Page::Component::Select2

          view 'app/views/import/github/new.html.haml' do
            element :personal_access_token_field
            element :authenticate_button
          end

          view 'app/assets/javascripts/import_entities/import_projects/components/provider_repo_table_row.vue' do
            element :project_import_row
            element :project_path_field
            element :import_button
            element :project_path_content
            element :go_to_project_button
            element :import_status_indicator
          end

          view "app/assets/javascripts/import_entities/components/group_dropdown.vue" do
            element :target_namespace_selector_dropdown
          end

          # Add personal access token
          #
          # @param [String] personal_access_token
          # @return [void]
          def add_personal_access_token(personal_access_token)
            # If for some reasons this process is retried, user cannot re-enter github token in the same group
            # In this case skip this step and proceed to import project row
            return unless has_element?(:personal_access_token_field)

            fill_element(:personal_access_token_field, personal_access_token)
            click_element(:authenticate_button)
            finished_loading?
          end

          # Import project
          #
          # @param [String] source_project_name
          # @param [String] target_group_path
          # @return [void]
          def import!(gh_project_name, target_group_path, project_name)
            within_element(:project_import_row, source_project: gh_project_name) do
              click_element(:target_namespace_selector_dropdown)
              click_element(:target_group_dropdown_item, group_name: target_group_path)
              fill_element(:project_path_field, project_name)

              retry_until do
                click_element(:import_button)
                # Make sure import started before waiting for completion
                has_no_element?(:import_status_indicator, text: "Not started", wait: 1)
              end
            end
          end

          # Check Go to project button present
          #
          # @param [String] gh_project_name
          # @return [Boolean]
          def has_go_to_project_button?(gh_project_name)
            within_element(:project_import_row, source_project: gh_project_name) do
              has_element?(:go_to_project_button)
            end
          end

          # Check if import page has a successfully imported project
          #
          # @param [String] source_project_name
          # @param [Integer] wait
          # @return [Boolean]
          def has_imported_project?(gh_project_name, wait: QA::Support::WaitForRequests::DEFAULT_MAX_WAIT_TIME)
            within_element(:project_import_row, source_project: gh_project_name, skip_finished_loading_check: true) do
              wait_until(
                max_duration: wait,
                sleep_interval: 5,
                reload: false,
                skip_finished_loading_check_on_refresh: true
              ) do
                has_element?(:import_status_indicator, text: "Complete")
              end
            end
          end

          alias_method :wait_for_success, :has_imported_project?
        end
      end
    end
  end
end
