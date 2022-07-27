# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Secure Files', :js do
  let(:project) { create(:project) }
  let(:user) { create(:user) }

  before do
    stub_feature_flags(ci_secure_files_read_only: false)
    project.add_maintainer(user)
    sign_in(user)
  end

  context 'when the :ci_secure_files feature flag is enabled' do
    before do
      stub_feature_flags(ci_secure_files: true)

      visit project_settings_ci_cd_path(project)
    end

    context 'authenticated user with admin permissions' do
      it 'shows the secure files settings' do
        expect(page).to have_content('Secure Files')
      end
    end
  end

  context 'when the :ci_secure_files feature flag is disabled' do
    before do
      stub_feature_flags(ci_secure_files: false)

      visit project_settings_ci_cd_path(project)
    end

    context 'authenticated user with admin permissions' do
      it 'does not shows the secure files settings' do
        expect(page).not_to have_content('Secure Files')
      end
    end
  end

  it 'user sees the Secure Files list component' do
    visit project_settings_ci_cd_path(project)

    within '#js-secure-files' do
      expect(page).to have_content('There are no secure files yet.')
    end
  end

  it 'prompts the user to confirm before deleting a file' do
    file = create(:ci_secure_file, project: project)

    visit project_settings_ci_cd_path(project)

    within '#js-secure-files' do
      expect(page).to have_content(file.name)

      find('button.btn-danger-secondary').click
    end

    expect(page).to have_content("Delete #{file.name}?")

    click_on('Delete secure file')

    visit project_settings_ci_cd_path(project)

    within '#js-secure-files' do
      expect(page).not_to have_content(file.name)
    end
  end

  it 'displays an uploaded file in the file list' do
    visit project_settings_ci_cd_path(project)

    within '#js-secure-files' do
      expect(page).to have_content('There are no secure files yet.')

      page.attach_file('spec/fixtures/ci_secure_files/upload-keystore.jks') do
        click_button 'Upload File'
      end

      expect(page).to have_content('upload-keystore.jks')
    end
  end

  it 'displays an error when a duplicate file upload is attempted' do
    create(:ci_secure_file, project: project, name: 'upload-keystore.jks')
    visit project_settings_ci_cd_path(project)

    within '#js-secure-files' do
      expect(page).to have_content('upload-keystore.jks')

      page.attach_file('spec/fixtures/ci_secure_files/upload-keystore.jks') do
        click_button 'Upload File'
      end

      expect(page).to have_content('A file with this name already exists.')
    end
  end
end
