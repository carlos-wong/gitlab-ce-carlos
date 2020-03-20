# frozen_string_literal: true

require 'spec_helper'

describe PagesDomains::ObtainLetsEncryptCertificateService do
  include LetsEncryptHelpers

  let(:pages_domain) { create(:pages_domain, :without_certificate, :without_key) }
  let(:service) { described_class.new(pages_domain) }

  before do
    stub_lets_encrypt_settings
  end

  around do |example|
    Sidekiq::Testing.fake! do
      example.run
    end
  end

  def expect_to_create_acme_challenge
    expect(::PagesDomains::CreateAcmeOrderService).to receive(:new).with(pages_domain)
      .and_wrap_original do |m, *args|
      create_service = m.call(*args)

      expect(create_service).to receive(:execute)

      create_service
    end
  end

  def stub_lets_encrypt_order(url, status)
    order = ::Gitlab::LetsEncrypt::Order.new(acme_order_double(status: status))

    allow_next_instance_of(::Gitlab::LetsEncrypt::Client) do |instance|
      allow(instance).to receive(:load_order).with(url).and_return(order)
    end

    order
  end

  context 'when there is no acme order' do
    it 'creates acme order and schedules next step' do
      expect_to_create_acme_challenge
      expect(PagesDomainSslRenewalWorker).to(
        receive(:perform_in).with(described_class::CHALLENGE_PROCESSING_DELAY, pages_domain.id)
          .and_return(nil).once
      )

      service.execute
    end
  end

  context 'when there is expired acme order' do
    let!(:existing_order) do
      create(:pages_domain_acme_order, :expired, pages_domain: pages_domain)
    end

    it 'removes acme order and creates new one' do
      expect_to_create_acme_challenge

      service.execute

      expect(PagesDomainAcmeOrder.find_by_id(existing_order.id)).to be_nil
    end
  end

  %w(pending processing).each do |status|
    context "there is an order in '#{status}' status" do
      let(:existing_order) do
        create(:pages_domain_acme_order, pages_domain: pages_domain)
      end

      before do
        stub_lets_encrypt_order(existing_order.url, status)
      end

      it 'does not raise errors' do
        expect do
          service.execute
        end.not_to raise_error
      end
    end
  end

  context 'when order is ready' do
    let(:existing_order) do
      create(:pages_domain_acme_order, pages_domain: pages_domain)
    end

    let!(:api_order) do
      stub_lets_encrypt_order(existing_order.url, 'ready')
    end

    it 'request certificate and schedules next step' do
      expect(api_order).to receive(:request_certificate).and_call_original
      expect(PagesDomainSslRenewalWorker).to(
        receive(:perform_in).with(described_class::CERTIFICATE_PROCESSING_DELAY, pages_domain.id)
          .and_return(nil).once
      )

      service.execute
    end
  end

  context 'when order is valid' do
    let(:existing_order) do
      create(:pages_domain_acme_order, pages_domain: pages_domain)
    end

    let!(:api_order) do
      stub_lets_encrypt_order(existing_order.url, 'valid')
    end

    let(:certificate) do
      key = OpenSSL::PKey.read(existing_order.private_key)

      subject = "/C=BE/O=Test/OU=Test/CN=#{pages_domain.domain}"

      cert = OpenSSL::X509::Certificate.new
      cert.subject = cert.issuer = OpenSSL::X509::Name.parse(subject)
      cert.not_before = Time.now
      cert.not_after = 1.year.from_now
      cert.public_key = key.public_key
      cert.serial = 0x0
      cert.version = 2

      ef = OpenSSL::X509::ExtensionFactory.new
      ef.subject_certificate = cert
      ef.issuer_certificate = cert
      cert.extensions = [
        ef.create_extension("basicConstraints", "CA:TRUE", true),
        ef.create_extension("subjectKeyIdentifier", "hash")
      ]
      cert.add_extension ef.create_extension("authorityKeyIdentifier",
                                             "keyid:always,issuer:always")

      cert.sign key, OpenSSL::Digest::SHA1.new

      cert.to_pem
    end

    before do
      expect(api_order).to receive(:certificate) { certificate }
    end

    it 'saves private_key and certificate for domain' do
      service.execute

      expect(pages_domain.key).to be_present
      expect(pages_domain.certificate).to eq(certificate)
    end

    it 'marks certificate as gitlab_provided' do
      service.execute

      expect(pages_domain.certificate_source).to eq("gitlab_provided")
    end

    it 'removes order from database' do
      service.execute

      expect(PagesDomainAcmeOrder.find_by_id(existing_order.id)).to be_nil
    end
  end
end
