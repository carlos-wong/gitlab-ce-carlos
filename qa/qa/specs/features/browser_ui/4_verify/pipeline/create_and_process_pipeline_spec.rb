# frozen_string_literal: true

module QA
  context 'Verify', :docker do
    describe 'Pipeline creation and processing' do
      let(:executor) { "qa-runner-#{Time.now.to_i}" }
      let(:max_wait) { 30 }

      let(:project) do
        Resource::Project.fabricate_via_api! do |project|
          project.name = 'project-with-pipeline'
        end
      end

      before do
        Resource::Runner.fabricate! do |runner|
          runner.project = project
          runner.name = executor
          runner.tags = [executor]
        end
      end

      after do
        Service::DockerRun::GitlabRunner.new(executor).remove!
      end

      it 'users creates a pipeline which gets processed', :smoke do
        Flow::Login.sign_in

        Resource::Repository::Commit.fabricate_via_api! do |commit|
          commit.project = project
          commit.commit_message = 'Add .gitlab-ci.yml'
          commit.add_files(
            [
              {
                file_path: '.gitlab-ci.yml',
                content: <<~YAML
                  test-success:
                    tags:
                      - #{executor}
                    script: echo 'OK'

                  test-failure:
                    tags:
                      - #{executor}
                    script:
                      - echo 'FAILURE'
                      - exit 1

                  test-tags:
                    tags:
                     - invalid
                    script: echo 'NOOP'

                  test-artifacts:
                    tags:
                      - #{executor}
                    script: mkdir my-artifacts; echo "CONTENTS" > my-artifacts/artifact.txt
                    artifacts:
                      paths:
                      - my-artifacts/
                YAML
              }
            ]
          )
        end.project.visit!

        Page::Project::Menu.perform(&:click_ci_cd_pipelines)
        Page::Project::Pipeline::Index.perform(&:click_on_latest_pipeline)

        {
          'test-success': :passed,
          'test-failure': :failed,
          'test-tags': :pending,
          'test-artifacts': :passed
        }.each do |job, status|
          Page::Project::Pipeline::Show.perform do |pipeline|
            pipeline.click_job(job)
          end

          Page::Project::Job::Show.perform do |show|
            expect(show).to public_send("be_#{status}")
            show.click_element(:pipeline_path, Page::Project::Pipeline::Show)
          end
        end
      end
    end
  end
end
