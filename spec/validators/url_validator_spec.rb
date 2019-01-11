# frozen_string_literal: true

require 'spec_helper'

describe UrlValidator do
  let!(:badge) { build(:badge, link_url: 'http://www.example.com') }
  subject { validator.validate_each(badge, :link_url, badge.link_url) }

  include_examples 'url validator examples', described_class::DEFAULT_PROTOCOLS

  describe 'validations' do
    include_context 'invalid urls'

    let(:validator) { described_class.new(attributes: [:link_url]) }

    it 'returns error when url is nil' do
      expect(validator.validate_each(badge, :link_url, nil)).to be_nil
      expect(badge.errors.first[1]).to eq 'must be a valid URL'
    end

    it 'returns error when url is empty' do
      expect(validator.validate_each(badge, :link_url, '')).to be_nil
      expect(badge.errors.first[1]).to eq 'must be a valid URL'
    end

    it 'does not allow urls with CR or LF characters' do
      aggregate_failures do
        urls_with_CRLF.each do |url|
          expect(validator.validate_each(badge, :link_url, url)[0]).to eq 'is blocked: URI is invalid'
        end
      end
    end
  end

  context 'by default' do
    let(:validator) { described_class.new(attributes: [:link_url]) }

    it 'does not block urls pointing to localhost' do
      badge.link_url = 'https://127.0.0.1'

      subject

      expect(badge.errors.empty?).to be true
    end

    it 'does not block urls pointing to the local network' do
      badge.link_url = 'https://192.168.1.1'

      subject

      expect(badge.errors.empty?).to be true
    end

    it 'strips urls' do
      badge.link_url = "\n\r\n\nhttps://127.0.0.1\r\n\r\n\n\n\n"

      # It's unusual for a validator to modify its arguments. Some extensions,
      # such as attr_encrypted, freeze the string to signal that modifications
      # will not be persisted, so freeze this string to ensure the scheme is
      # compatible with them.
      badge.link_url.freeze

      subject

      expect(badge.errors).to be_empty
      expect(badge.link_url).to eq('https://127.0.0.1')
    end
  end

  context 'when allow_localhost is set to false' do
    let(:validator) { described_class.new(attributes: [:link_url], allow_localhost: false) }

    it 'blocks urls pointing to localhost' do
      badge.link_url = 'https://127.0.0.1'

      subject

      expect(badge.errors.empty?).to be false
    end
  end

  context 'when allow_local_network is set to false' do
    let(:validator) { described_class.new(attributes: [:link_url], allow_local_network: false) }

    it 'blocks urls pointing to the local network' do
      badge.link_url = 'https://192.168.1.1'

      subject

      expect(badge.errors.empty?).to be false
    end
  end

  context 'when ports is' do
    let(:validator) { described_class.new(attributes: [:link_url], ports: ports) }

    context 'empty' do
      let(:ports) { [] }

      it 'does not block any port' do
        subject

        expect(badge.errors.empty?).to be true
      end
    end

    context 'set' do
      let(:ports) { [443] }

      it 'blocks urls with a different port' do
        subject

        expect(badge.errors.empty?).to be false
      end
    end
  end

  context 'when enforce_user is' do
    let(:url) { 'http://$user@example.com'}
    let(:validator) { described_class.new(attributes: [:link_url], enforce_user: enforce_user) }

    context 'true' do
      let(:enforce_user) { true }

      it 'checks user format' do
        badge.link_url = url

        subject

        expect(badge.errors.empty?).to be false
      end
    end

    context 'false (default)' do
      let(:enforce_user) { false }

      it 'does not check user format' do
        badge.link_url = url

        subject

        expect(badge.errors.empty?).to be true
      end
    end
  end

  context 'when ascii_only is' do
    let(:url) { 'https://𝕘itⅼαƄ.com/foo/foo.bar'}
    let(:validator) { described_class.new(attributes: [:link_url], ascii_only: ascii_only) }

    context 'true' do
      let(:ascii_only) { true }

      it 'prevents unicode characters' do
        badge.link_url = url

        subject

        expect(badge.errors.empty?).to be false
      end
    end

    context 'false (default)' do
      let(:ascii_only) { false }

      it 'does not prevent unicode characters' do
        badge.link_url = url

        subject

        expect(badge.errors.empty?).to be true
      end
    end
  end

  context 'when enforce_sanitization is' do
    let(:validator) { described_class.new(attributes: [:link_url], enforce_sanitization: enforce_sanitization) }
    let(:unsafe_url) { "https://replaceme.com/'><script>alert(document.cookie)</script>" }
    let(:safe_url) { 'https://replaceme.com/path/to/somewhere' }

    let(:unsafe_internal_url) do
      Gitlab.config.gitlab.protocol + '://' + Gitlab.config.gitlab.host +
        "/'><script>alert(document.cookie)</script>"
    end

    context 'true' do
      let(:enforce_sanitization) { true }

      it 'prevents unsafe urls' do
        badge.link_url = unsafe_url

        subject

        expect(badge.errors.empty?).to be false
      end

      it 'prevents unsafe internal urls' do
        badge.link_url = unsafe_internal_url

        subject

        expect(badge.errors.empty?).to be false
      end

      it 'allows safe urls' do
        badge.link_url = safe_url

        subject

        expect(badge.errors.empty?).to be true
      end
    end

    context 'false' do
      let(:enforce_sanitization) { false }

      it 'allows unsafe urls' do
        badge.link_url = unsafe_url

        subject

        expect(badge.errors.empty?).to be true
      end
    end
  end
end
