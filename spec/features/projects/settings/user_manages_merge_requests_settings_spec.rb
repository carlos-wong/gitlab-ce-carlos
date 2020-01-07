# frozen_string_literal: true
require 'spec_helper'

describe 'Projects > Settings > User manages merge request settings' do
  let(:user) { create(:user) }
  let(:project) { create(:project, :public, namespace: user.namespace, path: 'gitlab', name: 'sample') }

  before do
    sign_in(user)
    visit edit_project_path(project)
  end

  it 'shows "Merge commit" strategy' do
    page.within '#js-merge-request-settings' do
      expect(page).to have_content 'Merge commit'
    end
  end

  it 'shows "Merge commit with semi-linear history " strategy' do
    page.within '#js-merge-request-settings' do
      expect(page).to have_content 'Merge commit with semi-linear history'
    end
  end

  it 'shows "Fast-forward merge" strategy' do
    page.within '#js-merge-request-settings' do
      expect(page).to have_content 'Fast-forward merge'
    end
  end

  context 'when Merge Request and Pipelines are initially enabled', :js do
    context 'when Pipelines are initially enabled' do
      it 'shows the Merge Requests settings' do
        expect(page).to have_content 'Pipelines must succeed'
        expect(page).to have_content 'All discussions must be resolved'

        within('.sharing-permissions-form') do
          find('.project-feature-controls[data-for="project[project_feature_attributes][merge_requests_access_level]"] .project-feature-toggle').click
          find('input[value="Save changes"]').send_keys(:return)
        end

        expect(page).not_to have_content 'Pipelines must succeed'
        expect(page).not_to have_content 'All discussions must be resolved'
      end
    end

    context 'when Pipelines are initially disabled', :js do
      before do
        project.project_feature.update_attribute('builds_access_level', ProjectFeature::DISABLED)
        visit edit_project_path(project)
      end

      it 'shows the Merge Requests settings that do not depend on Builds feature' do
        expect(page).to have_content 'Pipelines must succeed'
        expect(page).to have_content 'All discussions must be resolved'

        within('.sharing-permissions-form') do
          find('.project-feature-controls[data-for="project[project_feature_attributes][builds_access_level]"] .project-feature-toggle').click
          find('input[value="Save changes"]').send_keys(:return)
        end

        expect(page).to have_content 'Pipelines must succeed'
        expect(page).to have_content 'All discussions must be resolved'
      end
    end
  end

  context 'when Merge Request are initially disabled', :js do
    before do
      project.project_feature.update_attribute('merge_requests_access_level', ProjectFeature::DISABLED)
      visit edit_project_path(project)
    end

    it 'does not show the Merge Requests settings' do
      expect(page).not_to have_content 'Pipelines must succeed'
      expect(page).not_to have_content 'All discussions must be resolved'

      within('.sharing-permissions-form') do
        find('.project-feature-controls[data-for="project[project_feature_attributes][merge_requests_access_level]"] .project-feature-toggle').click
        find('input[value="Save changes"]').send_keys(:return)
      end

      expect(page).to have_content 'Pipelines must succeed'
      expect(page).to have_content 'All discussions must be resolved'
    end
  end

  describe 'Checkbox to enable merge request link', :js do
    it 'is initially checked' do
      checkbox = find_field('project_printing_merge_request_link_enabled')
      expect(checkbox).to be_checked
    end

    it 'when unchecked sets :printing_merge_request_link_enabled to false' do
      uncheck('project_printing_merge_request_link_enabled')
      within('.merge-request-settings-form') do
        find('.rspec-save-merge-request-changes')
        click_on('Save changes')
      end

      find('.flash-notice')
      checkbox = find_field('project_printing_merge_request_link_enabled')

      expect(checkbox).not_to be_checked

      project.reload
      expect(project.printing_merge_request_link_enabled).to be(false)
    end
  end

  describe 'Checkbox to remove source branch after merge', :js do
    it 'is initially checked' do
      checkbox = find_field('project_remove_source_branch_after_merge')
      expect(checkbox).to be_checked
    end

    it 'when unchecked sets :remove_source_branch_after_merge to false' do
      uncheck('project_remove_source_branch_after_merge')
      within('.merge-request-settings-form') do
        find('.qa-save-merge-request-changes')
        click_on('Save changes')
      end

      find('.flash-notice')
      checkbox = find_field('project_remove_source_branch_after_merge')

      expect(checkbox).not_to be_checked

      project.reload
      expect(project.remove_source_branch_after_merge).to be(false)
    end
  end
end
