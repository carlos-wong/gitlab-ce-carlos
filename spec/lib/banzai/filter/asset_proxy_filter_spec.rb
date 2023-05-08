# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Banzai::Filter::AssetProxyFilter, feature_category: :team_planning do
  include FilterSpecHelper

  def image(path)
    %(<img src="#{path}" />)
  end

  it 'does not replace if disabled' do
    stub_asset_proxy_setting(enabled: false)

    context = described_class.transform_context({})
    src     = 'http://example.com/test.png'
    doc     = filter(image(src), context)

    expect(doc.at_css('img')['src']).to eq src
  end

  context 'during initialization' do
    after do
      Gitlab.config.asset_proxy['enabled'] = false
    end

    it '#initialize_settings' do
      stub_application_setting(asset_proxy_enabled: true)
      stub_application_setting(asset_proxy_secret_key: 'shared-secret')
      stub_application_setting(asset_proxy_url: 'https://assets.example.com')
      stub_application_setting(asset_proxy_allowlist: %w(gitlab.com *.mydomain.com))

      described_class.initialize_settings

      expect(Gitlab.config.asset_proxy.enabled).to be_truthy
      expect(Gitlab.config.asset_proxy.secret_key).to eq 'shared-secret'
      expect(Gitlab.config.asset_proxy.url).to eq 'https://assets.example.com'
      expect(Gitlab.config.asset_proxy.allowlist).to eq %w(gitlab.com *.mydomain.com)
      expect(Gitlab.config.asset_proxy.domain_regexp).to eq(/^(gitlab\.com|.*?\.mydomain\.com)$/i)
    end

    context 'when allowlist is empty' do
      it 'defaults to the install domain' do
        stub_application_setting(asset_proxy_enabled: true)
        stub_application_setting(asset_proxy_allowlist: [])

        described_class.initialize_settings

        expect(Gitlab.config.asset_proxy.allowlist).to eq [Gitlab.config.gitlab.host]
      end
    end

    it 'supports deprecated whitelist settings' do
      stub_application_setting(asset_proxy_enabled: true)
      stub_application_setting(asset_proxy_whitelist: %w(foo.com bar.com))
      stub_application_setting(asset_proxy_allowlist: [])

      described_class.initialize_settings

      expect(Gitlab.config.asset_proxy.allowlist).to eq %w(foo.com bar.com)
    end
  end

  context 'when properly configured' do
    before do
      stub_asset_proxy_setting(enabled: true)
      stub_asset_proxy_setting(secret_key: 'shared-secret')
      stub_asset_proxy_setting(url: 'https://assets.example.com')
      stub_asset_proxy_setting(allowlist: %W(gitlab.com *.mydomain.com #{Gitlab.config.gitlab.host}))
      stub_asset_proxy_setting(domain_regexp: described_class.compile_allowlist(Gitlab.config.asset_proxy.allowlist))
      @context = described_class.transform_context({})
    end

    it 'replaces img src' do
      src     = 'http://example.com/test.png'
      new_src = 'https://assets.example.com/08df250eeeef1a8cf2c761475ac74c5065105612/687474703a2f2f6578616d706c652e636f6d2f746573742e706e67'
      doc     = filter(image(src), @context)

      expect(doc.at_css('img')['src']).to eq new_src
      expect(doc.at_css('img')['data-canonical-src']).to eq src
    end

    it 'replaces invalid URLs' do
      src     = '///example.com/test.png'
      new_src = 'https://assets.example.com/3368d2c7b9bed775bdd1e811f36a4b80a0dcd8ab/2f2f2f6578616d706c652e636f6d2f746573742e706e67'
      doc     = filter(image(src), @context)

      expect(doc.at_css('img')['src']).to eq new_src
      expect(doc.at_css('img')['data-canonical-src']).to eq src
    end

    it 'skips internal images' do
      src      = "#{Gitlab.config.gitlab.url}/test.png"
      doc      = filter(image(src), @context)

      expect(doc.at_css('img')['src']).to eq src
    end

    it 'skip relative urls' do
      src = "/test.png"
      doc = filter(image(src), @context)

      expect(doc.at_css('img')['src']).to eq src
    end

    it 'skips single domain' do
      src = "http://gitlab.com/test.png"
      doc = filter(image(src), @context)

      expect(doc.at_css('img')['src']).to eq src
    end

    it 'skips single domain and ignores url in query string' do
      src = "http://gitlab.com/test.png?url=http://example.com/test.png"
      doc = filter(image(src), @context)

      expect(doc.at_css('img')['src']).to eq src
    end

    it 'skips wildcarded domain' do
      src = "http://images.mydomain.com/test.png"
      doc = filter(image(src), @context)

      expect(doc.at_css('img')['src']).to eq src
    end
  end
end
