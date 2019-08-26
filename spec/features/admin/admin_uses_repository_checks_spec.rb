# frozen_string_literal: true

require 'rails_helper'

describe 'Admin uses repository checks' do
  include StubENV

  before do
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
    sign_in(create(:admin))
  end

  it 'to trigger a single check' do
    project = create(:project)
    visit_admin_project_page(project)

    page.within('.repository-check') do
      click_button 'Trigger repository check'
    end

    expect(page).to have_content('Repository check was triggered')
  end

  it 'to see a single failed repository check', :js do
    project = create(:project)
    project.update_columns(
      last_repository_check_failed: true,
      last_repository_check_at: Time.now
    )
    visit_admin_project_page(project)

    page.within('.alert') do
      expect(page.text).to match(/Last repository check \(just now\) failed/)
    end
  end

  it 'to clear all repository checks', :js do
    visit repository_admin_application_settings_path

    expect(RepositoryCheck::ClearWorker).to receive(:perform_async)

    accept_confirm { find(:link, 'Clear all repository checks').send_keys(:return) }

    expect(page).to have_content('Started asynchronous removal of all repository check states.')
  end

  def visit_admin_project_page(project)
    visit admin_project_path(project)
  end
end
