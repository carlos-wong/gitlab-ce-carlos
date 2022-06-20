# frozen_string_literal: true

module QA
  RSpec.describe 'Package', :orchestrated, :packages, :object_storage do
    describe 'Helm Registry' do
      using RSpec::Parameterized::TableSyntax
      include Runtime::Fixtures
      include Support::Helpers::MaskToken
      include_context 'packages registry qa scenario'

      let(:package_name) { "gitlab_qa_helm-#{SecureRandom.hex(8)}" }
      let(:package_version) { '1.3.7' }
      let(:package_type) { 'helm' }

      where(:case_name, :authentication_token_type, :testcase) do
        'using personal access token' | :personal_access_token | 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347586'
        'using ci job token'          | :ci_job_token          | 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347587'
        'using project deploy token'  | :project_deploy_token  | 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347588'
      end

      with_them do
        let(:username) do
          case authentication_token_type
          when :personal_access_token
            Runtime::User.username
          when :ci_job_token
            'gitlab-ci-token'
          when :project_deploy_token
            project_deploy_token.username
          end
        end

        let(:access_token) do
          case authentication_token_type
          when :personal_access_token
            use_ci_variable(name: 'PERSONAL_ACCESS_TOKEN', value: personal_access_token, project: package_project)
            use_ci_variable(name: 'PERSONAL_ACCESS_TOKEN', value: personal_access_token, project: client_project)
          when :ci_job_token
            '${CI_JOB_TOKEN}'
          when :project_deploy_token
            use_ci_variable(name: 'PROJECT_DEPLOY_TOKEN', value: project_deploy_token.token, project: package_project)
            use_ci_variable(name: 'PROJECT_DEPLOY_TOKEN', value: project_deploy_token.token, project: client_project)
          end
        end

        it "pushes and pulls a helm chart", testcase: params[:testcase] do
          Support::Retrier.retry_on_exception(max_attempts: 3, sleep_interval: 2) do
            Resource::Repository::Commit.fabricate_via_api! do |commit|
              helm_upload_yaml = ERB.new(read_fixture('package_managers/helm', 'helm_upload_package.yaml.erb')).result(binding)
              helm_chart_yaml = ERB.new(read_fixture('package_managers/helm', 'Chart.yaml.erb')).result(binding)

              commit.project = package_project
              commit.commit_message = 'Add .gitlab-ci.yml'
              commit.add_files([
                                {
                                  file_path: '.gitlab-ci.yml',
                                  content: helm_upload_yaml
                                },
                                {
                                  file_path: 'Chart.yaml',
                                  content: helm_chart_yaml
                                }
              ])
            end
          end

          package_project.visit!

          Flow::Pipeline.visit_latest_pipeline

          Page::Project::Pipeline::Show.perform do |pipeline|
            pipeline.click_job('deploy')
          end

          Page::Project::Job::Show.perform do |job|
            expect(job).to be_successful(timeout: 800)
          end

          Page::Project::Menu.perform(&:click_packages_link)

          Page::Project::Packages::Index.perform do |index|
            expect(index).to have_package(package_name)

            index.click_package(package_name)
          end

          Page::Project::Packages::Show.perform do |show|
            expect(show).to have_package_info(package_name, package_version)
          end

          Support::Retrier.retry_on_exception(max_attempts: 3, sleep_interval: 2) do
            Resource::Repository::Commit.fabricate_via_api! do |commit|
              helm_install_yaml = ERB.new(read_fixture('package_managers/helm', 'helm_install_package.yaml.erb')).result(binding)

              commit.project = client_project
              commit.commit_message = 'Add .gitlab-ci.yml'
              commit.add_files([
                {
                  file_path: '.gitlab-ci.yml',
                  content: helm_install_yaml
                }
              ])
            end
          end

          client_project.visit!

          Flow::Pipeline.visit_latest_pipeline

          Page::Project::Pipeline::Show.perform do |pipeline|
            pipeline.click_job('pull')
          end

          Page::Project::Job::Show.perform do |job|
            expect(job).to be_successful(timeout: 800)
          end
        end
      end
    end
  end
end
