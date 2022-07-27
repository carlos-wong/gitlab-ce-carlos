# frozen_string_literal: true

module QA
  RSpec.describe 'Create', quarantine: {
    issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/352525',
    type: :test_environment,
    only: { job: 'review-qa-*' }
  } do
    describe 'Push mirror a repository over HTTP' do
      it 'configures and syncs LFS objects for a (push) mirrored repository', :aggregate_failures, testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347847' do
        Runtime::Browser.visit(:gitlab, Page::Main::Login)
        Page::Main::Login.perform(&:sign_in_using_credentials)

        target_project = Resource::Project.fabricate_via_api! do |project|
          project.name = 'push-mirror-target-project'
        end
        target_project_uri = target_project.repository_http_location.uri
        target_project_uri.user = Runtime::User.username

        source_project_push = Resource::Repository::ProjectPush.fabricate! do |push|
          push.file_name = 'README.md'
          push.file_content = '# This is a test project'
          push.commit_message = 'Add README.md'
          push.use_lfs = true
        end
        source_project_push.project.visit!

        Page::Project::Menu.perform(&:go_to_repository_settings)
        Page::Project::Settings::Repository.perform do |settings|
          settings.expand_mirroring_repositories do |mirror_settings|
            # Configure the source project to push to the target project
            mirror_settings.repository_url = target_project_uri
            mirror_settings.mirror_direction = 'Push'
            mirror_settings.authentication_method = 'Password'
            mirror_settings.password = Runtime::User.password
            mirror_settings.mirror_repository
            mirror_settings.update(target_project_uri) # rubocop:disable Rails/SaveBang
            mirror_settings.verify_update(target_project_uri)
          end
        end

        # Check that the target project has the commit from the source
        target_project.visit!
        Page::Project::Show.perform do |project_page|
          expect { project_page.has_file?('README.md') }.to eventually_be_truthy.within(max_duration: 60, reload_page: page), "Expected a file named README.md but it did not appear."
          expect(project_page).to have_readme_content('The rendered file could not be displayed because it is stored in LFS')
        end
      end
    end
  end
end
