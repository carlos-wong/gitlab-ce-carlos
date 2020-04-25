# frozen_string_literal: true

require 'spec_helper'

describe 'Admin browses logs' do
  before do
    sign_in(create(:admin))
  end

  it 'shows available log files' do
    visit admin_logs_path

    expect(page).to have_link 'application_json.log'
    expect(page).to have_link 'git_json.log'
    expect(page).to have_link 'test.log'
    expect(page).to have_link 'sidekiq.log'
    expect(page).to have_link 'repocheck.log'
    expect(page).to have_link 'kubernetes.log'
  end
end
