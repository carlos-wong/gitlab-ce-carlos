# frozen_string_literal: true

require 'spec_helper'

# TODO: remove this file together with FF https://gitlab.com/gitlab-org/gitlab/-/issues/366244
RSpec.describe 'Developer updates tag' do
  let(:user) { create(:user) }
  let(:group) { create(:group) }
  let(:project) { create(:project, :repository, namespace: group) }

  before do
    project.add_developer(user)
    sign_in(user)
    stub_feature_flags(edit_tag_release_notes_via_release_page: false)
    visit project_tags_path(project)
  end

  context 'from the tags list page' do
    it 'updates the release notes' do
      find("li > .row-fixed-content.controls a.btn-edit[href='/#{project.full_path}/-/tags/v1.1.0/release/edit']").click

      fill_in 'release_description', with: 'Awesome release notes'
      click_button 'Save changes'

      expect(page).to have_current_path(
        project_tag_path(project, 'v1.1.0'), ignore_query: true)
      expect(page).to have_content 'v1.1.0'
      expect(page).to have_content 'Awesome release notes'
    end

    it 'description has emoji autocomplete', :js do
      page.within(first('.content-list .controls')) do
        click_link 'Edit release notes'
      end

      find('#release_description').native.send_keys('')
      fill_in 'release_description', with: ':'

      expect(page).to have_selector('.atwho-view')
    end
  end

  context 'from a specific tag page' do
    it 'updates the release notes' do
      click_on 'v1.1.0'
      click_link 'Edit release notes'
      fill_in 'release_description', with: 'Awesome release notes'
      click_button 'Save changes'

      expect(page).to have_current_path(
        project_tag_path(project, 'v1.1.0'), ignore_query: true)
      expect(page).to have_content 'v1.1.0'
      expect(page).to have_content 'Awesome release notes'
    end
  end
end
