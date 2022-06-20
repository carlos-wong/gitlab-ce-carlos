# frozen_string_literal: true

module QA
  RSpec.describe 'Verify', :runner do
    describe 'Runner registration' do
      let(:executor) { "qa-runner-#{Time.now.to_i}" }
      let!(:runner) do
        Resource::Runner.fabricate! do |runner|
          runner.name = executor
          runner.tags = ['e2e-test']
        end
      end

      after do
        runner.remove_via_api!
      end

      it 'user registers a new specific runner', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/348025' do
        Flow::Login.sign_in

        runner.project.visit!

        Page::Project::Menu.perform(&:go_to_ci_cd_settings)
        Page::Project::Settings::CiCd.perform do |settings|
          settings.expand_runners_settings do |page|
            expect(page).to have_content(executor)
            expect(page).to have_online_runner
          end
        end
      end
    end
  end
end
