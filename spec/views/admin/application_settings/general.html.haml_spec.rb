# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/application_settings/general.html.haml' do
  let(:app_settings) { Gitlab::CurrentSettings.current_application_settings }
  let(:user) { create(:admin) }

  before do
    assign(:application_setting, app_settings)
    allow(view).to receive(:current_user).and_return(user)
  end

  describe 'sourcegraph integration' do
    let(:sourcegraph_flag) { true }

    before do
      allow(Gitlab::Sourcegraph).to receive(:feature_available?).and_return(sourcegraph_flag)
    end

    context 'when sourcegraph feature is enabled' do
      it 'show the form' do
        render

        expect(rendered).to have_field('application_setting_sourcegraph_enabled')
      end
    end

    context 'when sourcegraph feature is disabled' do
      let(:sourcegraph_flag) { false }

      it 'show the form' do
        render

        expect(rendered).not_to have_field('application_setting_sourcegraph_enabled')
      end
    end
  end

  describe 'prompt user about registration features' do
    context 'when service ping is enabled' do
      before do
        stub_application_setting(usage_ping_enabled: true)
      end

      it_behaves_like 'does not render registration features prompt', :application_setting_disabled_repository_size_limit
    end

    context 'with no license and service ping disabled' do
      before do
        stub_application_setting(usage_ping_enabled: false)

        if Gitlab.ee?
          allow(License).to receive(:current).and_return(nil)
        end
      end

      it_behaves_like 'renders registration features prompt', :application_setting_disabled_repository_size_limit
    end
  end

  describe 'add license' do
    before do
      render
    end

    it 'does not show the Add License section' do
      expect(rendered).not_to have_css('#js-add-license-toggle')
    end
  end

  describe 'jira connect application key' do
    it 'shows the jira connect application key section' do
      render

      expect(rendered).to have_css('#js-jira_connect-settings')
    end

    context 'when the jira_connect_oauth feature flag is disabled' do
      before do
        stub_feature_flags(jira_connect_oauth: false)
      end

      it 'does not show the jira connect application key section' do
        render

        expect(rendered).not_to have_css('#js-jira_connect-settings')
      end
    end
  end

  describe 'sign-up restrictions' do
    it 'renders js-signup-form tag' do
      render

      expect(rendered).to match 'id="js-signup-form"'
      expect(rendered).to match ' data-minimum-password-length='
    end
  end

  describe 'error tracking integration' do
    context 'with error tracking feature flag enabled' do
      before do
        stub_feature_flags(gitlab_error_tracking: true)

        render
      end

      it 'expects error tracking settings to be available' do
        expect(rendered).to have_field('application_setting_error_tracking_api_url')
      end

      it 'expects display token and reset token to be available' do
        expect(rendered).to have_content(app_settings.error_tracking_access_token)
        expect(rendered).to have_button('Reset error tracking access token')
      end
    end

    context 'with error tracking feature flag disabled' do
      it 'expects error tracking settings to not be avaiable' do
        stub_feature_flags(gitlab_error_tracking: false)

        render

        expect(rendered).not_to have_field('application_setting_error_tracking_api_url')
      end
    end
  end
end
