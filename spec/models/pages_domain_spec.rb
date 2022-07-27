# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PagesDomain do
  using RSpec::Parameterized::TableSyntax

  subject(:pages_domain) { described_class.new }

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to have_many(:serverless_domain_clusters) }
  end

  describe '.for_project' do
    it 'returns domains assigned to project' do
      domain = create(:pages_domain, :with_project)
      create(:pages_domain) # unrelated domain

      expect(described_class.for_project(domain.project)).to eq([domain])
    end
  end

  describe 'validate domain' do
    subject(:pages_domain) { build(:pages_domain, domain: domain) }

    context 'is unique' do
      let(:domain) { 'my.domain.com' }

      it { is_expected.to validate_uniqueness_of(:domain).case_insensitive }
    end

    describe "hostname" do
      {
        'my.domain.com'    => true,
        '123.456.789'      => true,
        '0x12345.com'      => true,
        '0123123'          => true,
        'a-reserved.com'   => true,
        'a.b-reserved.com' => true,
        'reserved.com'     => true,
        '_foo.com'         => false,
        'a.reserved.com'   => false,
        'a.b.reserved.com' => false,
        nil                => false
      }.each do |value, validity|
        context "domain #{value.inspect} validity" do
          before do
            allow(Settings.pages).to receive(:host).and_return('reserved.com')
          end

          let(:domain) { value }

          it { expect(pages_domain.valid?).to eq(validity) }
        end
      end
    end

    describe "HTTPS-only" do
      using RSpec::Parameterized::TableSyntax

      let(:domain) { 'my.domain.com' }

      let(:project) do
        instance_double(Project, pages_https_only?: pages_https_only)
      end

      let(:pages_domain) do
        build(:pages_domain, certificate: certificate, key: key,
              auto_ssl_enabled: auto_ssl_enabled).tap do |pd|
          allow(pd).to receive(:project).and_return(project)
          pd.valid?
        end
      end

      where(:pages_https_only, :certificate, :key, :auto_ssl_enabled, :errors_on) do
        attributes = attributes_for(:pages_domain)
        cert, key = attributes.fetch_values(:certificate, :key)

        true  | nil  | nil | false | %i(certificate key)
        true  | nil  | nil | true  | []
        true  | cert | nil | false | %i(key)
        true  | cert | nil | true  | %i(key)
        true  | nil  | key | false | %i(certificate key)
        true  | nil  | key | true  | %i(key)
        true  | cert | key | false | []
        true  | cert | key | true  | []
        false | nil  | nil | false | []
        false | nil  | nil | true  | []
        false | cert | nil | false | %i(key)
        false | cert | nil | true  | %i(key)
        false | nil  | key | false | %i(key)
        false | nil  | key | true  | %i(key)
        false | cert | key | false | []
        false | cert | key | true  | []
      end

      with_them do
        it "is adds the expected errors" do
          expect(pages_domain.errors.attribute_names).to eq errors_on
        end
      end
    end
  end

  describe 'when certificate is specified' do
    let(:domain) { build(:pages_domain) }

    it 'saves validity time' do
      domain.save!

      expect(domain.certificate_valid_not_before).to be_like_time(Time.zone.parse("2020-03-16 14:20:34 UTC"))
      expect(domain.certificate_valid_not_after).to be_like_time(Time.zone.parse("2220-01-28 14:20:34 UTC"))
    end
  end

  describe 'validate certificate' do
    subject { domain }

    context 'serverless domain' do
      it 'requires certificate and key to be present' do
        expect(build(:pages_domain, :without_certificate, :without_key, usage: :serverless)).not_to be_valid
        expect(build(:pages_domain, :without_certificate, usage: :serverless)).not_to be_valid
        expect(build(:pages_domain, :without_key, usage: :serverless)).not_to be_valid
      end
    end

    context 'with matching key' do
      let(:domain) { build(:pages_domain) }

      it { is_expected.to be_valid }
    end

    context 'when no certificate is specified' do
      let(:domain) { build(:pages_domain, :without_certificate) }

      it { is_expected.not_to be_valid }
    end

    context 'when no key is specified' do
      let(:domain) { build(:pages_domain, :without_key) }

      it { is_expected.not_to be_valid }
    end

    context 'for not matching key' do
      let(:domain) { build(:pages_domain, :with_missing_chain) }

      it { is_expected.not_to be_valid }
    end

    context 'when certificate is expired' do
      let(:domain) do
        build(:pages_domain, :with_trusted_expired_chain)
      end

      context 'when certificate is being changed' do
        it "adds error to certificate" do
          domain.valid?

          expect(domain.errors.attribute_names).to contain_exactly(:key, :certificate)
        end
      end

      context 'when certificate is already saved' do
        it "doesn't add error to certificate" do
          domain.save!(validate: false)

          domain.valid?

          expect(domain.errors.attribute_names).to contain_exactly(:key)
        end
      end
    end

    context 'with ecdsa certificate' do
      it "is valid" do
        domain = build(:pages_domain, :ecdsa)

        expect(domain).to be_valid
      end

      context 'when curve is set explicitly by parameters' do
        it 'adds errors to private key' do
          domain = build(:pages_domain, :explicit_ecdsa)

          expect(domain).to be_invalid

          expect(domain.errors[:key]).not_to be_empty
        end
      end
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:verification_code) }
  end

  describe 'default values' do
    it 'defaults wildcard to false' do
      expect(subject.wildcard).to eq(false)
    end

    it 'defaults scope to project' do
      expect(subject.scope).to eq('project')
    end

    it 'defaults usage to pages' do
      expect(subject.usage).to eq('pages')
    end
  end

  describe '#verification_code' do
    subject { pages_domain.verification_code }

    it 'is set automatically with 128 bits of SecureRandom data' do
      expect(SecureRandom).to receive(:hex).with(16) { 'verification code' }

      is_expected.to eq('verification code')
    end
  end

  describe '#keyed_verification_code' do
    subject { pages_domain.keyed_verification_code }

    it { is_expected.to eq("gitlab-pages-verification-code=#{pages_domain.verification_code}") }
  end

  describe '#verification_domain' do
    subject { pages_domain.verification_domain }

    it { is_expected.to be_nil }

    it 'is a well-known subdomain if the domain is present' do
      pages_domain.domain = 'example.com'

      is_expected.to eq('_gitlab-pages-verification-code.example.com')
    end
  end

  describe '#url' do
    subject { domain.url }

    let(:domain) { build(:pages_domain) }

    it { is_expected.to eq("https://#{domain.domain}") }

    context 'without the certificate' do
      let(:domain) { build(:pages_domain, :without_certificate) }

      it { is_expected.to eq("http://#{domain.domain}") }
    end
  end

  describe '#has_matching_key?' do
    subject { domain.has_matching_key? }

    let(:domain) { build(:pages_domain) }

    it { is_expected.to be_truthy }

    context 'for invalid key' do
      let(:domain) { build(:pages_domain, :with_missing_chain) }

      it { is_expected.to be_falsey }
    end
  end

  describe '#has_intermediates?' do
    subject { domain.has_intermediates? }

    context 'for self signed' do
      let(:domain) { build(:pages_domain) }

      it { is_expected.to be_truthy }
    end

    context 'for missing certificate chain' do
      let(:domain) { build(:pages_domain, :with_missing_chain) }

      it { is_expected.to be_falsey }
    end

    context 'for trusted certificate chain' do
      # We only validate that we can to rebuild the trust chain, for certificates
      # We assume that 'AddTrustExternalCARoot' needed to validate the chain is in trusted store.
      # It will be if ca-certificates is installed on Debian/Ubuntu/Alpine

      let(:domain) { build(:pages_domain, :with_trusted_chain) }

      it { is_expected.to be_truthy }
    end
  end

  describe '#expired?' do
    subject { domain.expired? }

    context 'for valid' do
      let(:domain) { build(:pages_domain) }

      it { is_expected.to be_falsey }
    end

    context 'for expired' do
      let(:domain) { build(:pages_domain, :with_expired_certificate) }

      it { is_expected.to be_truthy }
    end
  end

  describe '#subject' do
    let(:domain) { build(:pages_domain) }

    subject { domain.subject }

    it { is_expected.to eq('/CN=test-certificate') }
  end

  describe '#certificate_text' do
    let(:domain) { build(:pages_domain) }

    subject { domain.certificate_text }

    # We test only existence of output, since the output is long
    it { is_expected.not_to be_empty }
  end

  describe "#https?" do
    context "when a certificate is present" do
      subject { build(:pages_domain) }

      it { is_expected.to be_https }
    end

    context "when no certificate is present" do
      subject { build(:pages_domain, :without_certificate) }

      it { is_expected.not_to be_https }
    end
  end

  describe '#user_provided_key' do
    subject { domain.user_provided_key }

    context 'when certificate is provided by user' do
      let(:domain) { create(:pages_domain) }

      it 'returns key' do
        is_expected.to eq(domain.key)
      end
    end

    context 'when certificate is provided by gitlab' do
      let(:domain) { create(:pages_domain, :letsencrypt) }

      it 'returns nil' do
        is_expected.to be_nil
      end
    end
  end

  describe '#user_provided_certificate' do
    subject { domain.user_provided_certificate }

    context 'when certificate is provided by user' do
      let(:domain) { create(:pages_domain) }

      it 'returns key' do
        is_expected.to eq(domain.certificate)
      end
    end

    context 'when certificate is provided by gitlab' do
      let(:domain) { create(:pages_domain, :letsencrypt) }

      it 'returns nil' do
        is_expected.to be_nil
      end
    end
  end

  shared_examples 'certificate setter' do |attribute, setter_name, old_certificate_source, new_certificate_source|
    let(:domain) do
      create(:pages_domain, certificate_source: old_certificate_source)
    end

    let(:old_value) { domain.public_send(attribute) }

    subject { domain.public_send(setter_name, new_value) }

    context 'when value has been changed' do
      let(:new_value) { 'new_value' }

      it "assignes new value to #{attribute}" do
        expect do
          subject
        end.to change { domain.public_send(attribute) }.from(old_value).to('new_value')
      end

      it 'changes certificate source' do
        expect do
          subject
        end.to change { domain.certificate_source }.from(old_certificate_source).to(new_certificate_source)
      end
    end

    context 'when value has not been not changed' do
      let(:new_value) { old_value }

      it 'does not change certificate source' do
        expect do
          subject
        end.not_to change { domain.certificate_source }.from(old_certificate_source)
      end
    end
  end

  describe '#user_provided_key=' do
    include_examples('certificate setter', 'key', 'user_provided_key=',
                     'gitlab_provided', 'user_provided')
  end

  describe '#gitlab_provided_key=' do
    include_examples('certificate setter', 'key', 'gitlab_provided_key=',
                     'user_provided', 'gitlab_provided')
  end

  describe '#user_provided_certificate=' do
    include_examples('certificate setter', 'certificate', 'user_provided_certificate=',
                     'gitlab_provided', 'user_provided')
  end

  describe '#gitlab_provided_certificate=' do
    include_examples('certificate setter', 'certificate', 'gitlab_provided_certificate=',
                     'user_provided', 'gitlab_provided')
  end

  describe '#save' do
    context 'when we failed to obtain ssl certificate' do
      let(:domain) { create(:pages_domain, auto_ssl_enabled: true, auto_ssl_failed: true) }

      it 'clears failure if auto ssl is disabled' do
        expect do
          domain.update!(auto_ssl_enabled: false)
        end.to change { domain.auto_ssl_failed }.from(true).to(false)
      end

      it 'does not clear failure on unrelated updates' do
        expect do
          domain.update!(verified_at: Time.current)
        end.not_to change { domain.auto_ssl_failed }.from(true)
      end
    end
  end

  describe '.for_removal' do
    subject { described_class.for_removal }

    context 'when domain is not schedule for removal' do
      let!(:domain) { create :pages_domain }

      it 'does not return domain' do
        is_expected.to be_empty
      end
    end

    context 'when domain is scheduled for removal yesterday' do
      let!(:domain) { create :pages_domain, remove_at: 1.day.ago }

      it 'returns domain' do
        is_expected.to eq([domain])
      end
    end

    context 'when domain is scheduled for removal tomorrow' do
      let!(:domain) { create :pages_domain, remove_at: 1.day.from_now }

      it 'does not return domain' do
        is_expected.to be_empty
      end
    end
  end

  describe '.instance_serverless' do
    subject { described_class.instance_serverless }

    before do
      create(:pages_domain, wildcard: true)
      create(:pages_domain, :instance_serverless)
      create(:pages_domain, scope: :instance)
      create(:pages_domain, :instance_serverless)
      create(:pages_domain, usage: :serverless)
    end

    it 'returns domains that are wildcard, instance-level, and serverless' do
      expect(subject.length).to eq(2)

      subject.each do |domain|
        expect(domain.wildcard).to eq(true)
        expect(domain.usage).to eq('serverless')
        expect(domain.scope).to eq('instance')
      end
    end
  end

  describe '.need_auto_ssl_renewal' do
    subject { described_class.need_auto_ssl_renewal }

    let!(:domain_with_user_provided_certificate) { create(:pages_domain) }
    let!(:domain_with_expired_user_provided_certificate) do
      create(:pages_domain, :with_expired_certificate)
    end

    let!(:domain_with_user_provided_certificate_and_auto_ssl) do
      create(:pages_domain, auto_ssl_enabled: true)
    end

    let!(:domain_with_gitlab_provided_certificate) { create(:pages_domain, :letsencrypt) }
    let!(:domain_with_expired_gitlab_provided_certificate) do
      create(:pages_domain, :letsencrypt, :with_expired_certificate)
    end

    let!(:domain_with_failed_auto_ssl) do
      create(:pages_domain, auto_ssl_enabled: true, auto_ssl_failed: true)
    end

    it 'contains only domains needing ssl renewal' do
      is_expected.to(
        contain_exactly(
          domain_with_user_provided_certificate_and_auto_ssl,
          domain_with_expired_gitlab_provided_certificate
        )
      )
    end
  end

  describe '#pages_virtual_domain' do
    let(:project) { create(:project) }
    let(:pages_domain) { create(:pages_domain, project: project) }

    context 'when there are no pages deployed for the project' do
      it 'returns nil' do
        expect(pages_domain.pages_virtual_domain).to be_nil
      end
    end

    context 'when there are pages deployed for the project' do
      let(:virtual_domain) { pages_domain.pages_virtual_domain }

      before do
        project.mark_pages_as_deployed
        project.update_pages_deployment!(create(:pages_deployment, project: project))
      end

      it 'returns the virual domain when there are pages deployed for the project' do
        expect(virtual_domain).to be_an_instance_of(Pages::VirtualDomain)
        expect(virtual_domain.lookup_paths).not_to be_empty
        expect(virtual_domain.cache_key).to eq("pages_domain_for_project_#{project.id}")
      end

      context 'when :cache_pages_domain_api is disabled' do
        before do
          stub_feature_flags(cache_pages_domain_api: false)
        end

        it 'returns the virual domain when there are pages deployed for the project' do
          expect(virtual_domain).to be_an_instance_of(Pages::VirtualDomain)
          expect(virtual_domain.lookup_paths).not_to be_empty
          expect(virtual_domain.cache_key).to be_nil
        end
      end
    end
  end

  describe '.find_by_domain_case_insensitive' do
    it 'lookup is case-insensitive' do
      pages_domain = create(:pages_domain, domain: "Pages.IO")

      expect(PagesDomain.find_by_domain_case_insensitive('pages.io')).to eq(pages_domain)
    end
  end
end
