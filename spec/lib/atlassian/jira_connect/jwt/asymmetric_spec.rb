# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Atlassian::JiraConnect::Jwt::Asymmetric do
  describe '#valid?' do
    let_it_be(:private_key) { OpenSSL::PKey::RSA.generate 3072 }

    subject(:asymmetric_jwt) { described_class.new(jwt, verification_claims) }

    let(:verification_claims) { jwt_claims }
    let(:jwt_claims) { { aud: aud, iss: client_key, qsh: qsh } }
    let(:aud) { 'https://test.host/-/jira_connect' }
    let(:client_key) { '1234' }
    let(:public_key_id) { '123e4567-e89b-12d3-a456-426614174000' }
    let(:jwt_headers) { { kid: public_key_id } }
    let(:jwt) { JWT.encode(jwt_claims, private_key, 'RS256', jwt_headers) }
    let(:public_key) { private_key.public_key }
    let(:install_keys_url) { "https://connect-install-keys.atlassian.com/#{public_key_id}" }
    let(:qsh) do
      Atlassian::Jwt.create_query_string_hash('https://gitlab.test/events/installed', 'POST', 'https://gitlab.test')
    end

    before do
      stub_request(:get, install_keys_url)
        .to_return(body: public_key.to_s, status: 200)
    end

    it 'returns true when verified with public key from CDN' do
      expect(JWT).to receive(:decode).twice.and_call_original

      expect(asymmetric_jwt).to be_valid

      expect(WebMock).to have_requested(:get, install_keys_url)
    end

    context 'JWT does not contain a key ID' do
      let(:public_key_id) { nil }

      it { is_expected.not_to be_valid }
    end

    context 'JWT contains a key ID that is not a valid UUID4' do
      let(:public_key_id) { '123' }

      it { is_expected.not_to be_valid }
    end

    context 'public key can not be retrieved' do
      before do
        stub_request(:get, install_keys_url).to_return(body: '', status: 404)
      end

      it { is_expected.not_to be_valid }
    end

    context 'retrieving the public raises an error' do
      before do
        allow(Gitlab::HTTP).to receive(:get).and_raise(SocketError)
      end

      it { is_expected.not_to be_valid }
    end

    context 'token decoding raises an error' do
      before do
        allow(JWT).to receive(:decode).and_call_original
        allow(JWT).to receive(:decode).with(
          jwt, anything, true,
          { aud: anything, verify_aud: true, iss: client_key, verify_iss: true, algorithm: 'RS256' }
        ).and_raise(JWT::DecodeError)
      end

      it { is_expected.not_to be_valid }
    end

    context 'when iss could not be verified' do
      let(:verification_claims) { { aud: jwt_claims[:aud], iss: 'some other iss', qsh: jwt_claims[:qsh] } }

      it { is_expected.not_to be_valid }
    end

    context 'when qsh could not be verified' do
      let(:verification_claims) { { aud: jwt_claims[:aud], iss: client_key, qsh: 'some other qsh' } }

      it { is_expected.not_to be_valid }
    end
  end

  describe '#iss_claim' do
    subject { asymmetric_jwt.iss_claim }

    let(:asymmetric_jwt) { described_class.new('123', anything) }

    it { is_expected.to eq(nil) }

    context 'when jwt is verified' do
      before do
        asymmetric_jwt.instance_variable_set(:@claims, { 'iss' => 'client_key' })
      end

      it { is_expected.to eq('client_key') }
    end
  end
end
