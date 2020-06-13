# frozen_string_literal: true

require 'spec_helper'

describe 'User edits Release', :js do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:release) { create(:release, project: project, name: 'The first release' ) }
  let_it_be(:user) { create(:user) }
  let(:show_feature_flag) { true }

  before do
    stub_feature_flags(release_show_page: show_feature_flag)

    project.add_developer(user)

    gitlab_sign_in(user)

    visit edit_project_release_path(project, release)

    wait_for_requests
  end

  def fill_out_form_and_click(button_to_click)
    fill_in 'Release title', with: 'Updated Release title'
    fill_in 'Release notes', with: 'Updated Release notes'

    click_link_or_button button_to_click

    wait_for_all_requests
  end

  it 'renders the breadcrumbs' do
    within('.breadcrumbs') do
      expect(page).to have_content("#{project.creator.name} #{project.name} Edit Release")

      expect(page).to have_link(project.creator.name, href: user_path(project.creator))
      expect(page).to have_link(project.name, href: project_path(project))
      expect(page).to have_link('Edit Release', href: edit_project_release_path(project, release))
    end
  end

  it 'renders the edit Release form' do
    expect(page).to have_content('Releases are based on Git tags. We recommend naming tags that fit within semantic versioning, for example v1.0, v2.0-pre.')

    expect(find_field('Tag name', { disabled: true }).value).to eq(release.tag)
    expect(find_field('Release title').value).to eq(release.name)
    expect(find_field('Release notes').value).to eq(release.description)

    expect(page).to have_button('Save changes')
    expect(page).to have_link('Cancel')
  end

  it 'does not update the Release when "Cancel" is clicked' do
    original_name = release.name
    original_description = release.description

    fill_out_form_and_click 'Cancel'

    release.reload

    expect(release.name).to eq(original_name)
    expect(release.description).to eq(original_description)
  end

  it 'updates the Release when "Save changes" is clicked' do
    fill_out_form_and_click 'Save changes'

    release.reload

    expect(release.name).to eq('Updated Release title')
    expect(release.description).to eq('Updated Release notes')
  end

  context 'when the release_show_page feature flag is disabled' do
    let(:show_feature_flag) { false }

    it 'redirects to the main Releases page when "Cancel" is clicked' do
      fill_out_form_and_click 'Cancel'

      expect(page).to have_current_path(project_releases_path(project))
    end

    it 'redirects to the main Releases page when "Save changes" is clicked' do
      fill_out_form_and_click 'Save changes'

      expect(page).to have_current_path(project_releases_path(project))
    end
  end

  context 'when the release_show_page feature flag is enabled' do
    it 'redirects to the previous page when "Cancel" is clicked when the url includes a back_url query parameter' do
      back_path = project_releases_path(project, params: { page: 2 })
      visit edit_project_release_path(project, release, params: { back_url: back_path })

      fill_out_form_and_click 'Cancel'

      expect(page).to have_current_path(back_path)
    end

    it 'redirects to the main Releases page when "Cancel" is clicked when the url does not include a back_url query parameter' do
      fill_out_form_and_click 'Cancel'

      expect(page).to have_current_path(project_releases_path(project))
    end

    it 'redirects to the dedicated Release page when "Save changes" is clicked' do
      fill_out_form_and_click 'Save changes'

      expect(page).to have_current_path(project_release_path(project, release))
    end
  end
end
