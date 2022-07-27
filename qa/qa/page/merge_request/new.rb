# frozen_string_literal: true

module QA
  module Page
    module MergeRequest
      class New < Page::Issuable::New
        view 'app/views/shared/issuable/_form.html.haml' do
          element :issuable_create_button, required: true
        end

        view 'app/views/projects/merge_requests/creations/_new_compare.html.haml' do
          element :compare_branches_button
          element :source_branch_dropdown
        end

        view 'app/views/projects/merge_requests/show.html.haml' do
          element :diffs_tab
        end

        view 'app/assets/javascripts/diffs/components/diff_file_header.vue' do
          element :file_name_content
        end

        def has_secure_description?(scanner_name)
          scanner_url_name = scanner_name.downcase.tr('_', '-')
          "Configure #{scanner_name} in `.gitlab-ci.yml` using the GitLab managed template. You can " \
            "[add variable overrides](https://docs.gitlab.com/ee/user/application_security/#{scanner_url_name}/#customizing-the-#{scanner_url_name}-settings) " \
            "to customize #{scanner_name} settings."
        end

        def click_compare_branches_and_continue
          click_element(:compare_branches_button)
        end

        def create_merge_request
          click_element(:issuable_create_button, Page::MergeRequest::Show)
        end

        def click_diffs_tab
          click_element(:diffs_tab)
          click_element(:dismiss_popover_button) if has_element?(:dismiss_popover_button, wait: 1)
        end

        def has_file?(file_name)
          has_element?(:file_name_content, text: file_name)
        end

        def select_source_branch(branch)
          click_element(:source_branch_dropdown)
          fill_element(:dropdown_input_field, branch)
          click_via_capybara(:click_on, branch)
        end
      end
    end
  end
end

QA::Page::MergeRequest::New.prepend_mod_with('Page::MergeRequest::New', namespace: QA)
