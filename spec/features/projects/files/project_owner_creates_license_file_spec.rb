# frozen_string_literal: true

require 'spec_helper'

describe 'Projects > Files > Project owner creates a license file', :js do
  let(:project) { create(:project, :repository) }
  let(:project_maintainer) { project.owner }

  before do
    stub_feature_flags(vue_file_list: false)
    project.repository.delete_file(project_maintainer, 'LICENSE',
      message: 'Remove LICENSE', branch_name: 'master')
    sign_in(project_maintainer)
    visit project_path(project)
  end

  it 'project maintainer creates a license file manually from a template' do
    visit project_tree_path(project, project.repository.root_ref)
    find('.add-to-tree').click
    click_link 'New file'

    fill_in :file_name, with: 'LICENSE'

    expect(page).to have_selector('.license-selector')

    select_template('MIT License')

    file_content = first('.file-editor')
    expect(file_content).to have_content('MIT License')
    expect(file_content).to have_content("Copyright (c) #{Time.now.year} #{project.namespace.human_name}")

    fill_in :commit_message, with: 'Add a LICENSE file', visible: true
    click_button 'Commit changes'

    expect(current_path).to eq(
      project_blob_path(project, 'master/LICENSE'))
    expect(page).to have_content('MIT License')
    expect(page).to have_content("Copyright (c) #{Time.now.year} #{project.namespace.human_name}")
  end

  it 'project maintainer creates a license file from the "Add license" link' do
    click_link 'Add license'

    expect(page).to have_content('New file')
    expect(current_path).to eq(
      project_new_blob_path(project, 'master'))
    expect(find('#file_name').value).to eq('LICENSE')
    expect(page).to have_selector('.license-selector')

    select_template('MIT License')

    file_content = first('.file-editor')
    expect(file_content).to have_content('MIT License')
    expect(file_content).to have_content("Copyright (c) #{Time.now.year} #{project.namespace.human_name}")

    fill_in :commit_message, with: 'Add a LICENSE file', visible: true
    click_button 'Commit changes'

    expect(current_path).to eq(
      project_blob_path(project, 'master/LICENSE'))
    expect(page).to have_content('MIT License')
    expect(page).to have_content("Copyright (c) #{Time.now.year} #{project.namespace.human_name}")
  end

  def select_template(template)
    page.within('.js-license-selector-wrap') do
      click_button 'Apply a license template'
      click_link template
      wait_for_requests
    end
  end
end
