# frozen_string_literal: true

require 'spec_helper'

describe 'Help Pages' do
  describe 'Get the main help page' do
    shared_examples_for 'help page' do |prefix: ''|
      it 'prefixes links correctly' do
        expect(page).to have_selector(%(div.documentation-index > table tbody tr td a[href="#{prefix}/help/api/README.md"]))
      end
    end

    context 'without a trailing slash' do
      before do
        visit help_path
      end

      it_behaves_like 'help page'
    end

    context 'with a trailing slash' do
      before do
        visit help_path + '/'
      end

      it_behaves_like 'help page'
    end

    context 'with a relative installation' do
      before do
        stub_config_setting(relative_url_root: '/gitlab')
        visit help_path
      end

      it_behaves_like 'help page', prefix: '/gitlab'
    end

    context 'quick link shortcuts', :js do
      before do
        visit help_path
      end

      it 'focuses search bar' do
        find('.js-trigger-search-bar').click

        expect(page).to have_selector('#search:focus')
      end

      it 'opens shortcuts help dialog' do
        find('.js-trigger-shortcut').click

        expect(page).to have_selector('#modal-shortcuts')
      end
    end
  end

  context 'in a production environment with version check enabled' do
    before do
      stub_application_setting(version_check_enabled: true)

      allow(Rails.env).to receive(:production?).and_return(true)
      allow(VersionCheck).to receive(:url).and_return('/version-check-url')

      sign_in(create(:user))
      visit help_path
    end

    it 'has a version check image' do
      # Check `data-src` due to lazy image loading
      expect(find('.js-version-status-badge', visible: false)['data-src'])
        .to end_with('/version-check-url')
    end
  end

  describe 'when help page is customized' do
    before do
      stub_application_setting(help_page_hide_commercial_content: true,
                               help_page_text: 'My Custom Text',
                               help_page_support_url: 'http://example.com/help')

      sign_in(create(:user))
      visit help_path
    end

    it 'displays custom help page text' do
      expect(page).to have_text "My Custom Text"
    end

    it 'hides marketing content when enabled' do
      expect(page).not_to have_link "Get a support subscription"
    end

    it 'uses a custom support url' do
      expect(page).to have_link "See our website for getting help", href: "http://example.com/help"
    end
  end
end
