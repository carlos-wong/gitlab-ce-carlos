# frozen_string_literal: true

module QA
  context 'Create' do
    describe 'Create, list, and delete branches via web' do
      master_branch = 'master'
      second_branch = 'second-branch'
      third_branch = 'third-branch'
      file_1_master = 'file.txt'
      file_2_master = 'other-file.txt'
      file_second_branch = 'file-2.txt'
      file_third_branch = 'file-3.txt'
      first_commit_message_of_master_branch = "Add #{file_1_master}"
      second_commit_message_of_master_branch = "Add #{file_2_master}"
      commit_message_of_second_branch = "Add #{file_second_branch}"
      commit_message_of_third_branch = "Add #{file_third_branch}"

      before do
        Runtime::Browser.visit(:gitlab, Page::Main::Login)
        Page::Main::Login.perform(&:sign_in_using_credentials)

        project = Resource::Project.fabricate! do |proj|
          proj.name = 'project-qa-test'
          proj.description = 'project for qa test'
        end

        Git::Repository.perform do |repository|
          repository.uri = project.repository_http_location.uri
          repository.use_default_credentials
          repository.try_add_credentials_to_netrc

          repository.act do
            clone
            configure_identity('GitLab QA', 'root@gitlab.com')
            commit_file(file_1_master, 'Test file content', first_commit_message_of_master_branch)
            push_changes
            checkout(second_branch, new_branch: true)
            commit_file(file_second_branch, 'File 2 content', commit_message_of_second_branch)
            push_changes(second_branch)
            checkout(master_branch)
            # This second commit on master is needed for the master branch to be ahead
            # of the second branch, and when the second branch is merged to master it will
            # show the 'merged' badge on it.
            # Refer to the below issue note:
            # https://gitlab.com/gitlab-org/gitlab-ce/issues/55524#note_126100848
            commit_file(file_2_master, 'Other test file content', second_commit_message_of_master_branch)
            push_changes
            merge(second_branch)
            push_changes
            checkout(third_branch, new_branch: true)
            commit_file(file_third_branch, 'File 3 content', commit_message_of_third_branch)
            push_changes(third_branch)
          end
        end
        project.wait_for_push commit_message_of_third_branch
        project.visit!
      end

      it 'branches are correctly listed after CRUD operations' do
        Page::Project::Menu.perform(&:go_to_repository_branches)

        expect(page).to have_content(master_branch)
        expect(page).to have_content(second_branch)
        expect(page).to have_content(third_branch)
        expect(page).to have_content("Merge branch 'second-branch'")
        expect(page).to have_content(commit_message_of_second_branch)
        expect(page).to have_content(commit_message_of_third_branch)

        Page::Project::Branches::Show.perform do |branches|
          expect(branches).to have_branch_with_badge(second_branch, 'merged')
        end

        Page::Project::Branches::Show.perform do |branches_view|
          branches_view.delete_branch(third_branch)
        end

        expect(page).not_to have_content(third_branch)

        Page::Project::Branches::Show.perform(&:delete_merged_branches)

        expect(page).to have_content(
          'Merged branches are being deleted. This can take some time depending on the number of branches. Please refresh the page to see changes.'
        )

        page.refresh
        Page::Project::Branches::Show.perform do |branches_view|
          branches_view.wait_for_texts_not_to_be_visible([commit_message_of_second_branch])
          expect(branches_view).not_to have_branch_title(second_branch)
        end
      end
    end
  end
end
