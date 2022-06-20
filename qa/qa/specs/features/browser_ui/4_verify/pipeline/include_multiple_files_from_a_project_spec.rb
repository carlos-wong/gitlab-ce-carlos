# frozen_string_literal: true

module QA
  RSpec.describe 'Verify', :runner do
    describe 'Include multiple files from a project' do
      let(:executor) { "qa-runner-#{Faker::Alphanumeric.alphanumeric(8)}" }
      let(:expected_text) { Faker::Lorem.sentence }
      let(:unexpected_text) { Faker::Lorem.sentence }

      let(:project) do
        Resource::Project.fabricate_via_api! do |project|
          project.name = 'project-with-pipeline-1'
        end
      end

      let(:other_project) do
        Resource::Project.fabricate_via_api! do |project|
          project.name = 'project-with-pipeline-2'
        end
      end

      let!(:runner) do
        Resource::Runner.fabricate! do |runner|
          runner.project = project
          runner.name = executor
          runner.tags = [executor]
        end
      end

      before do
        Flow::Login.sign_in
        add_included_files
        add_main_ci_file
        project.visit!
        Flow::Pipeline.visit_latest_pipeline(status: 'passed')
      end

      after do
        runner.remove_via_api!
      end

      it 'runs the pipeline with composed config', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/348087' do
        Page::Project::Pipeline::Show.perform do |pipeline|
          aggregate_failures 'pipeline has all expected jobs' do
            expect(pipeline).to have_job('build')
            expect(pipeline).to have_job('test')
            expect(pipeline).to have_job('deploy')
          end

          pipeline.click_job('test')
        end

        Page::Project::Job::Show.perform do |job|
          aggregate_failures 'main CI is not overridden' do
            expect(job.output).not_to have_content("#{unexpected_text}")
            expect(job.output).to have_content("#{expected_text}")
          end
        end
      end

      private

      def add_main_ci_file
        Resource::Repository::Commit.fabricate_via_api! do |commit|
          commit.project = project
          commit.commit_message = 'Add config file'
          commit.add_files([main_ci_file])
        end
      end

      def add_included_files
        Resource::Repository::Commit.fabricate_via_api! do |commit|
          commit.project = other_project
          commit.commit_message = 'Add files'
          commit.add_files([included_file_1, included_file_2])
        end
      end

      def main_ci_file
        {
          file_path: '.gitlab-ci.yml',
          content: <<~YAML
            include:
              - project: #{other_project.full_path}
                file:
                  - file1.yml
                  - file2.yml

            build:
              stage: build
              tags: ["#{executor}"]
              script: echo 'build'

            test:
              stage: test
              tags: ["#{executor}"]
              script: echo "#{expected_text}"
          YAML
        }
      end

      def included_file_1
        {
          file_path: 'file1.yml',
          content: <<~YAML
            test:
              stage: test
              tags: ["#{executor}"]
              script: echo "#{unexpected_text}"
          YAML
        }
      end

      def included_file_2
        {
          file_path: 'file2.yml',
          content: <<~YAML
            deploy:
              stage: deploy
              tags: ["#{executor}"]
              script: echo 'deploy'
          YAML
        }
      end
    end
  end
end
