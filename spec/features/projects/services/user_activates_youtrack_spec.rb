# frozen_string_literal: true

require 'spec_helper'

describe 'User activates issue tracker', :js do
  let(:user) { create(:user) }
  let(:project) { create(:project) }

  let(:url) { 'http://tracker.example.com' }

  def fill_form(disabled: false)
    uncheck 'Active' if disabled

    fill_in 'service_project_url', with: url
    fill_in 'service_issues_url', with: "#{url}/:id"
  end

  before do
    project.add_maintainer(user)
    sign_in(user)

    visit project_settings_integrations_path(project)
  end

  shared_examples 'external issue tracker activation' do |tracker:|
    describe 'user sets and activates the Service' do
      context 'when the connection test succeeds' do
        before do
          stub_request(:head, url).to_return(headers: { 'Content-Type' => 'application/json' })

          click_link(tracker)
          fill_form
          click_button('Test settings and save changes')
          wait_for_requests
        end

        it 'activates the service' do
          expect(page).to have_content("#{tracker} activated.")
          expect(current_path).to eq(project_settings_integrations_path(project))
        end

        it 'shows the link in the menu' do
          page.within('.nav-sidebar') do
            expect(page).to have_link(tracker, href: url)
          end
        end
      end

      context 'when the connection test fails' do
        it 'activates the service' do
          stub_request(:head, url).to_raise(Gitlab::HTTP::Error)

          click_link(tracker)
          fill_form
          click_button('Test settings and save changes')
          wait_for_requests

          expect(find('.flash-container-page')).to have_content 'Test failed.'
          expect(find('.flash-container-page')).to have_content 'Save anyway'

          find('.flash-alert .flash-action').click
          wait_for_requests

          expect(page).to have_content("#{tracker} activated.")
          expect(current_path).to eq(project_settings_integrations_path(project))
        end
      end
    end

    describe 'user disables the service' do
      before do
        click_link(tracker)
        fill_form(disabled: true)
        click_button('Save changes')
      end

      it 'saves but does not activate the service' do
        expect(page).to have_content("#{tracker} settings saved, but not activated.")
        expect(current_path).to eq(project_settings_integrations_path(project))
      end

      it 'does not show the external tracker link in the menu' do
        page.within('.nav-sidebar') do
          expect(page).not_to have_link(tracker, href: url)
        end
      end
    end
  end

  it_behaves_like 'external issue tracker activation', tracker: 'YouTrack'
end
