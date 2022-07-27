# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project navbar' do
  include NavbarStructureHelper
  include WaitForRequests

  include_context 'project navbar structure'

  let_it_be(:project) { create(:project, :repository) }

  let(:user) { project.first_owner }

  before do
    sign_in(user)

    stub_config(registry: { enabled: false })
    stub_feature_flags(harbor_registry_integration: false)
    insert_package_nav(_('Deployments'))
    insert_infrastructure_registry_nav
    insert_infrastructure_google_cloud_nav
  end

  it_behaves_like 'verified navigation bar' do
    before do
      visit project_path(project)
    end
  end

  context 'when value stream is available' do
    before do
      visit project_path(project)
    end

    it 'redirects to value stream when Analytics item is clicked' do
      page.within('.sidebar-top-level-items') do
        find('.shortcuts-analytics').click
      end

      wait_for_requests

      expect(page).to have_current_path(project_cycle_analytics_path(project))
    end
  end

  context 'when pages are available' do
    before do
      stub_config(pages: { enabled: true })

      insert_after_sub_nav_item(
        _('Packages & Registries'),
        within: _('Settings'),
        new_sub_nav_item_name: _('Pages')
      )

      visit project_path(project)
    end

    it_behaves_like 'verified navigation bar'
  end

  context 'when package registry is available' do
    before do
      stub_config(packages: { enabled: true })

      visit project_path(project)
    end

    it_behaves_like 'verified navigation bar'
  end

  context 'when container registry is available' do
    before do
      stub_config(registry: { enabled: true })

      insert_container_nav

      visit project_path(project)
    end

    it_behaves_like 'verified navigation bar'
  end

  context 'when harbor registry is available' do
    before do
      stub_feature_flags(harbor_registry_integration: true)

      insert_harbor_registry_nav(_('Infrastructure Registry'))

      visit project_path(project)
    end

    it_behaves_like 'verified navigation bar'
  end
end
