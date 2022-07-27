# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group Packages & Registries settings' do
  include WaitForRequests

  let(:user) { create(:user) }
  let(:group) { create(:group) }
  let(:sub_group) { create(:group, parent: group) }

  before do
    group.add_owner(user)
    sub_group.add_owner(user)
    sign_in(user)
  end

  context 'when packages feature is disabled on the group' do
    before do
      stub_packages_setting(enabled: false)
    end

    it 'the menu item is not visible' do
      visit group_path(group)

      settings_menu = find_settings_menu

      expect(settings_menu).not_to have_content 'Packages & Registries'
    end

    it 'renders 404 when navigating to page' do
      visit_settings_page

      expect(page).to have_content('Not Found')
    end
  end

  context 'when packages feature is enabled on the group' do
    it 'the menu item is visible' do
      visit group_path(group)

      settings_menu = find_settings_menu
      expect(settings_menu).to have_content 'Packages & Registries'
    end

    it 'has a page title set' do
      visit_settings_page

      expect(page).to have_title _('Packages & Registries')
    end

    it 'sidebar menu is open' do
      visit_settings_page

      sidebar = find('.nav-sidebar')
      expect(sidebar).to have_link _('Packages & Registries')
    end

    it 'has a Duplicate packages section', :js do
      visit_settings_page

      expect(page).to have_content('Duplicate packages')
    end

    it 'automatically saves changes to the server', :js do
      visit_settings_page

      within '[data-testid="maven-settings"]' do
        expect(page).to have_content('Reject packages with the same name and version')
        expect(page).not_to have_content('Exceptions')

        find('.gl-toggle').click

        expect(page).to have_content('Exceptions')

        visit_settings_page

        expect(page).to have_content('Exceptions')
      end
    end

    it 'shows an error on wrong regex', :js do
      visit_settings_page

      within '[data-testid="maven-settings"]' do
        expect(page).to have_content('Reject packages with the same name and version')

        find('.gl-toggle').click

        fill_in 'Exceptions', with: ')'

        # simulate blur event
        find('#maven-duplicated-settings-regex-input').native.send_keys(:tab)
      end

      expect(page).to have_content('is an invalid regexp')
    end

    context 'in a sub group' do
      it 'works correctly', :js do
        visit_sub_group_settings_page

        within '[data-testid="maven-settings"]' do
          expect(page).to have_content('Reject packages with the same name and version')

          find('.gl-toggle').click

          expect(page).to have_content('Exceptions')
        end
      end
    end
  end

  def find_settings_menu
    find('.shortcuts-settings ul')
  end

  def visit_settings_page
    visit group_settings_packages_and_registries_path(group)
  end

  def visit_sub_group_settings_page
    visit group_settings_packages_and_registries_path(sub_group)
  end
end
