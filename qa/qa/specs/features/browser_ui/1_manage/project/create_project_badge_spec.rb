# frozen_string_literal: true

module QA
  RSpec.describe 'Manage' do
    describe 'Create project badge', :reliable do
      let(:badge_name) { "project-badge-#{SecureRandom.hex(8)}" }
      let(:expected_badge_link_url) { "#{Runtime::Scenario.gitlab_address}/#{project.path_with_namespace}" }
      let(:expected_badge_image_url) { "#{Runtime::Scenario.gitlab_address}/#{project.path_with_namespace}/badges/main/pipeline.svg" }
      let(:project) do
        Resource::Project.fabricate_via_api! do |project|
          project.name = 'badge-test-project'
          project.initialize_with_readme = true
        end
      end

      before do
        Flow::Login.sign_in
        project.visit!
      end

      it 'creates project badge successfully', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/350065' do
        Resource::ProjectBadge.fabricate! do |badge|
          badge.name = badge_name
        end

        Page::Project::Settings::Main.perform do |project_settings|
          expect(project_settings).to have_notice('New badge added.')
        end

        Page::Component::Badges.perform do |badges|
          aggregate_failures do
            expect(badges).to have_badge(badge_name)
            expect(badges).to have_visible_badge_image_link(expected_badge_link_url)
            expect(badges.asset_exists?(expected_badge_image_url)).to be_truthy
          end
        end

        project.visit!

        Page::Project::Show.perform do |project|
          expect(project).to have_visible_badge_image_link(expected_badge_link_url)
          expect(project.asset_exists?(expected_badge_image_url)).to be_truthy
        end
      end

      after do
        project&.remove_via_api!
      end
    end
  end
end
