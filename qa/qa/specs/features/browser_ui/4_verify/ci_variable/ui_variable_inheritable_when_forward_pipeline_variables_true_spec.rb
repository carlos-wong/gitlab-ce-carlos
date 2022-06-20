# frozen_string_literal: true

module QA
  # TODO:
  # Remove FF :ci_trigger_forward_variables
  # when https://gitlab.com/gitlab-org/gitlab/-/issues/355572 is closed
  RSpec.describe 'Verify', :runner, feature_flag: {
    name: 'ci_trigger_forward_variables',
    scope: :global
  } do
    describe 'UI defined variable' do
      include_context 'variable inheritance test prep'

      before do
        add_ci_file(downstream1_project, [downstream1_ci_file])
        add_ci_file(upstream_project, [upstream_ci_file, upstream_child1_ci_file])

        start_pipeline_with_variable
        Page::Project::Pipeline::Show.perform do |show|
          Support::Waiter.wait_until { show.passed? }
        end
      end

      it(
        'is inheritable when forward:pipeline_variables is true',
        :aggregate_failures,
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/358197'
      ) do
        visit_job_page('child1', 'child1_job')
        verify_job_log_shows_variable_value

        page.go_back

        visit_job_page('downstream1', 'downstream1_job')
        verify_job_log_shows_variable_value
      end

      def upstream_ci_file
        {
          file_path: '.gitlab-ci.yml',
          content: <<~YAML
            stages:
              - test
              - deploy

            child1_trigger:
              stage: test
              trigger:
                include: .child1-ci.yml
                forward:
                  pipeline_variables: true

            downstream1_trigger:
              stage: deploy
              trigger:
                project: #{downstream1_project.full_path}
                forward:
                  pipeline_variables: true
          YAML
        }
      end
    end
  end
end
