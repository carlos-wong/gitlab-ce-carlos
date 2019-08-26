# frozen_string_literal: true

require 'spec_helper'

describe 'The group dashboard' do
  include ExternalAuthorizationServiceHelpers

  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe 'The top navigation' do
    it 'has all the expected links' do
      visit dashboard_groups_path

      within('.navbar') do
        expect(page).to have_button('Projects')
        expect(page).to have_button('Groups')
        expect(page).to have_link('Activity')
        expect(page).to have_link('Milestones')
        expect(page).to have_link('Snippets')
      end
    end

    it 'hides some links when an external authorization service is enabled' do
      enable_external_authorization_service_check
      visit dashboard_groups_path

      within('.navbar') do
        expect(page).to have_button('Projects')
        expect(page).to have_button('Groups')
        expect(page).not_to have_link('Activity')
        expect(page).not_to have_link('Milestones')
        expect(page).to have_link('Snippets')
      end
    end
  end
end
