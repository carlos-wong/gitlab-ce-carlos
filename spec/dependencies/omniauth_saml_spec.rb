# frozen_string_literal: true

require 'spec_helper'
require 'omniauth/strategies/saml'

describe 'processing of SAMLResponse in dependencies' do
  let(:mock_saml_response) { File.read('spec/fixtures/authentication/saml_response.xml') }
  let(:saml_strategy) { OmniAuth::Strategies::SAML.new({}) }
  let(:session_mock) { {} }
  let(:settings) { OpenStruct.new({ soft: false, idp_cert_fingerprint: 'something' }) }
  let(:auth_hash) { Gitlab::Auth::Saml::AuthHash.new(saml_strategy) }

  subject { auth_hash.authn_context }

  before do
    allow(saml_strategy).to receive(:session).and_return(session_mock)
    allow_any_instance_of(OneLogin::RubySaml::Response).to receive(:is_valid?).and_return(true)
    saml_strategy.send(:handle_response, mock_saml_response, {}, settings ) { }
  end

  it 'can extract AuthnContextClassRef from SAMLResponse param' do
    is_expected.to eq 'urn:oasis:names:tc:SAML:2.0:ac:classes:Password'
  end
end
