# frozen_string_literal: true

require 'spec_helper'

describe ::Gitlab::LetsEncrypt::Client do
  include LetsEncryptHelpers

  let(:client) { described_class.new }

  before do
    stub_application_setting(
      lets_encrypt_notification_email: 'myemail@test.example.com',
      lets_encrypt_terms_of_service_accepted: true
    )
  end

  let!(:stub_client) { stub_lets_encrypt_client }

  shared_examples 'ensures account registration' do
    it 'ensures account registration' do
      subject

      expect(stub_client).to have_received(:new_account).with(
        contact: 'mailto:myemail@test.example.com',
        terms_of_service_agreed: true
      )
    end

    it 'generates and stores private key and initialize acme client with it' do
      expect(Gitlab::CurrentSettings.lets_encrypt_private_key).to eq(nil)

      subject

      saved_private_key = Gitlab::CurrentSettings.lets_encrypt_private_key

      expect(saved_private_key).to be
      expect(Acme::Client).to have_received(:new).with(
        hash_including(private_key: eq_pem(saved_private_key))
      )
    end

    context 'when private key is saved in settings' do
      let!(:saved_private_key) do
        key = OpenSSL::PKey::RSA.new(4096).to_pem
        Gitlab::CurrentSettings.current_application_settings.update(lets_encrypt_private_key: key)
        key
      end

      it 'uses current value of private key' do
        subject

        expect(Acme::Client).to have_received(:new).with(
          hash_including(private_key: eq_pem(saved_private_key))
        )
        expect(Gitlab::CurrentSettings.lets_encrypt_private_key).to eq(saved_private_key)
      end
    end

    context 'when acme integration is disabled' do
      before do
        stub_application_setting(lets_encrypt_terms_of_service_accepted: false)
      end

      it 'raises error' do
        expect do
          subject
        end.to raise_error('Acme integration is disabled')
      end
    end
  end

  describe '#new_order' do
    subject(:new_order) { client.new_order('example.com') }

    before do
      order_double = instance_double('Acme::Order')
      allow(stub_client).to receive(:new_order).and_return(order_double)
    end

    include_examples 'ensures account registration'

    it 'returns order' do
      is_expected.to be_a(::Gitlab::LetsEncrypt::Order)
    end
  end

  describe '#load_order' do
    let(:url) { 'https://example.com/order' }
    subject { client.load_order(url) }

    before do
      acme_order = instance_double('Acme::Client::Resources::Order')
      allow(stub_client).to receive(:order).with(url: url).and_return(acme_order)
    end

    include_examples 'ensures account registration'

    it 'loads order' do
      is_expected.to be_a(::Gitlab::LetsEncrypt::Order)
    end
  end

  describe '#load_challenge' do
    let(:url) { 'https://example.com/challenge' }
    subject { client.load_challenge(url) }

    before do
      acme_challenge = instance_double('Acme::Client::Resources::Challenge')
      allow(stub_client).to receive(:challenge).with(url: url).and_return(acme_challenge)
    end

    include_examples 'ensures account registration'

    it 'loads challenge' do
      is_expected.to be_a(::Gitlab::LetsEncrypt::Challenge)
    end
  end

  describe '#enabled?' do
    subject { client.enabled? }

    context 'when terms of service are accepted' do
      it { is_expected.to eq(true) }

      context "when private_key isn't present and database is read only" do
        before do
          allow(::Gitlab::Database).to receive(:read_only?).and_return(true)
        end

        it 'returns false' do
          expect(::Gitlab::CurrentSettings.lets_encrypt_private_key).to eq(nil)

          is_expected.to eq(false)
        end
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(pages_auto_ssl: false)
        end

        it { is_expected.to eq(false) }
      end
    end

    context 'when terms of service are not accepted' do
      before do
        stub_application_setting(lets_encrypt_terms_of_service_accepted: false)
      end

      it { is_expected.to eq(false) }
    end
  end

  describe '#terms_of_service_url' do
    subject { client.terms_of_service_url }

    it 'returns valid url' do
      is_expected.to eq("https://letsencrypt.org/documents/LE-SA-v1.2-November-15-2017.pdf")
    end
  end
end
