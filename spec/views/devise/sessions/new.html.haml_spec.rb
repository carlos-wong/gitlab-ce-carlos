# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'devise/sessions/new' do
  describe 'marketing text' do
    subject { render(template: 'devise/sessions/new', layout: 'layouts/devise') }

    before do
      stub_devise
      disable_captcha
      allow(Gitlab).to receive(:com?).and_return(true)
    end

    it 'when flash is anything it renders marketing text' do
      flash[:notice] = "You can't do that"

      subject

      expect(rendered).to have_content('A complete DevOps platform')
    end

    it 'when flash notice is devise confirmed message it hides marketing text' do
      flash[:notice] = t(:confirmed, scope: [:devise, :confirmations])

      subject

      expect(rendered).not_to have_content('A complete DevOps platform')
    end
  end

  describe 'ldap' do
    include LdapHelpers

    let(:server) { { provider_name: 'ldapmain', label: 'LDAP' }.with_indifferent_access }

    before do
      enable_ldap
      stub_devise
      disable_captcha
      disable_sign_up
      disable_other_signin_methods

      allow(view).to receive(:experiment_enabled?).and_return(false)
    end

    it 'is shown when enabled' do
      render

      expect(rendered).to have_selector('.new-session-tabs')
      expect(rendered).to have_selector('[data-qa-selector="ldap_tab"]') # rubocop:disable QA/SelectorUsage
      expect(rendered).to have_field('LDAP Username')
    end

    it 'is not shown when LDAP sign in is disabled' do
      disable_ldap_sign_in

      render

      expect(rendered).to have_content('No authentication methods configured')
      expect(rendered).not_to have_selector('[data-qa-selector="ldap_tab"]') # rubocop:disable QA/SelectorUsage
      expect(rendered).not_to have_field('LDAP Username')
    end
  end

  describe 'Google Tag Manager' do
    let!(:gtm_id) { 'GTM-WWKMTWS'}

    subject { rendered }

    before do
      stub_devise
      disable_captcha
      stub_config(extra: { google_tag_manager_id: gtm_id, google_tag_manager_nonce_id: gtm_id })
    end

    describe 'when Google Tag Manager is enabled' do
      before do
        enable_gtm
        render
      end

      it { is_expected.to match /www.googletagmanager.com/ }
    end

    describe 'when Google Tag Manager is disabled' do
      before do
        disable_gtm
        render
      end

      it { is_expected.not_to match /www.googletagmanager.com/ }
    end
  end

  def disable_other_signin_methods
    allow(view).to receive(:password_authentication_enabled_for_web?).and_return(false)
    allow(view).to receive(:omniauth_enabled?).and_return(false)
  end

  def disable_sign_up
    allow(view).to receive(:allow_signup?).and_return(false)
  end

  def stub_devise
    allow(view).to receive(:devise_mapping).and_return(Devise.mappings[:user])
    allow(view).to receive(:resource).and_return(spy)
    allow(view).to receive(:resource_name).and_return(:user)
  end

  def enable_ldap
    stub_ldap_setting(enabled: true)
    allow(view).to receive(:ldap_servers).and_return([server])
    allow(view).to receive(:form_based_providers).and_return([:ldapmain])
    allow(view).to receive(:omniauth_callback_path).with(:user, 'ldapmain').and_return('/ldapmain')
  end

  def disable_ldap_sign_in
    allow(view).to receive(:ldap_sign_in_enabled?).and_return(false)
    allow(view).to receive(:ldap_servers).and_return([])
  end

  def disable_captcha
    allow(view).to receive(:captcha_enabled?).and_return(false)
    allow(view).to receive(:captcha_on_login_required?).and_return(false)
  end

  def disable_gtm
    allow(view).to receive(:google_tag_manager_enabled?).and_return(false)
  end

  def enable_gtm
    allow(view).to receive(:google_tag_manager_enabled?).and_return(true)
  end
end
