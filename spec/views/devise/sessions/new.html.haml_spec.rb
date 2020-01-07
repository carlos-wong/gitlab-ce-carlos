# frozen_string_literal: true

require 'spec_helper'

describe 'devise/sessions/new' do
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
      expect(rendered).to have_selector('[data-qa-selector="ldap_tab"]')
      expect(rendered).to have_field('LDAP Username')
    end

    it 'is not shown when LDAP sign in is disabled' do
      disable_ldap_sign_in

      render

      expect(rendered).to have_content('No authentication methods configured')
      expect(rendered).not_to have_selector('[data-qa-selector="ldap_tab"]')
      expect(rendered).not_to have_field('LDAP Username')
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
    assign(:ldap_servers, [server])
    allow(view).to receive(:form_based_providers).and_return([:ldapmain])
    allow(view).to receive(:omniauth_callback_path).with(:user, 'ldapmain').and_return('/ldapmain')
  end

  def disable_ldap_sign_in
    allow(view).to receive(:ldap_sign_in_enabled?).and_return(false)
    assign(:ldap_servers, [])
  end

  def disable_captcha
    allow(view).to receive(:captcha_enabled?).and_return(false)
    allow(view).to receive(:captcha_on_login_required?).and_return(false)
  end
end
