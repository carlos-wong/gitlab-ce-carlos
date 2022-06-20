# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Cluster agent registration', :js do
  let_it_be(:project) { create(:project, :custom_repo, files: { '.gitlab/agents/example-agent-1/config.yaml' => '' }) }
  let_it_be(:current_user) { create(:user, maintainer_projects: [project]) }

  before do
    allow(Gitlab::Kas).to receive(:enabled?).and_return(true)
    allow(Gitlab::Kas).to receive(:internal_url).and_return('kas.example.internal')

    allow_next_instance_of(Gitlab::Kas::Client) do |client|
      allow(client).to receive(:list_agent_config_files).and_return([
        double(agent_name: 'example-agent-1', path: '.gitlab/agents/example-agent-1/config.yaml'),
        double(agent_name: 'example-agent-2', path: '.gitlab/agents/example-agent-2/config.yaml')
      ])
      allow(client).to receive(:get_connected_agents).and_return([])
    end

    allow(Devise).to receive(:friendly_token).and_return('example-agent-token')

    sign_in(current_user)
    visit project_clusters_path(project)
  end

  it 'allows the user to select an agent to install, and displays the resulting agent token' do
    click_button('Connect a cluster')
    expect(page).to have_content('Register')

    click_button('Select an agent')
    click_button('example-agent-2')
    click_button('Register')

    expect(page).to have_content('You cannot see this token again after you close this window.')
    expect(page).to have_content('example-agent-token')
    expect(page).to have_content('helm upgrade --install')

    within find('.modal-footer') do
      click_button('Close')
    end

    expect(page).to have_link('example-agent-2')
  end
end
