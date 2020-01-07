# frozen_string_literal: true

require 'spec_helper'

describe OmniAuth::Strategies::SAML, type: :strategy do
  let(:idp_sso_target_url) { 'https://login.example.com/idp' }
  let(:strategy) { [OmniAuth::Strategies::SAML, { idp_sso_target_url: idp_sso_target_url }] }

  describe 'POST /users/auth/saml' do
    it 'redirects to the provider login page' do
      post '/users/auth/saml'

      expect(last_response).to redirect_to(/\A#{Regexp.quote(idp_sso_target_url)}/)
    end

    it 'stores request ID during request phase' do
      request_id = double
      allow_any_instance_of(OneLogin::RubySaml::Authrequest).to receive(:uuid).and_return(request_id)

      post '/users/auth/saml'
      expect(session['last_authn_request_id']).to eq(request_id)
    end
  end
end
