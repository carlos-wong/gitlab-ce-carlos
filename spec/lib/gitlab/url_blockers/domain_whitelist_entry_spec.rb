# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::UrlBlockers::DomainWhitelistEntry do
  let(:domain) { 'www.example.com' }

  describe '#initialize' do
    it 'initializes without port' do
      domain_whitelist_entry = described_class.new(domain)

      expect(domain_whitelist_entry.domain).to eq(domain)
      expect(domain_whitelist_entry.port).to be(nil)
    end

    it 'initializes with port' do
      port = 8080
      domain_whitelist_entry = described_class.new(domain, port: port)

      expect(domain_whitelist_entry.domain).to eq(domain)
      expect(domain_whitelist_entry.port).to eq(port)
    end
  end

  describe '#match?' do
    it 'matches when domain and port are equal' do
      port = 8080
      domain_whitelist_entry = described_class.new(domain, port: port)

      expect(domain_whitelist_entry).to be_match(domain, port)
    end

    it 'matches any port when port is nil' do
      domain_whitelist_entry = described_class.new(domain)

      expect(domain_whitelist_entry).to be_match(domain, 8080)
      expect(domain_whitelist_entry).to be_match(domain, 9090)
    end

    it 'does not match when port is present but requested_port is nil' do
      domain_whitelist_entry = described_class.new(domain, port: 8080)

      expect(domain_whitelist_entry).not_to be_match(domain, nil)
    end

    it 'matches when port and requested_port are nil' do
      domain_whitelist_entry = described_class.new(domain)

      expect(domain_whitelist_entry).to be_match(domain)
    end

    it 'does not match if domain is not equal' do
      domain_whitelist_entry = described_class.new(domain)

      expect(domain_whitelist_entry).not_to be_match('www.gitlab.com', 8080)
    end
  end
end
