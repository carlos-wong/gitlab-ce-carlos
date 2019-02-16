require 'spec_helper'

describe ApplicationSetting do
  let(:setting) { described_class.create_from_defaults }

  it { include(CacheableAttributes) }
  it { expect(described_class.current_without_cache).to eq(described_class.last) }

  it { expect(setting).to be_valid }
  it { expect(setting.uuid).to be_present }
  it { expect(setting).to have_db_column(:auto_devops_enabled) }

  describe 'validations' do
    let(:http)  { 'http://example.com' }
    let(:https) { 'https://example.com' }
    let(:ftp)   { 'ftp://example.com' }

    it { is_expected.to allow_value(nil).for(:home_page_url) }
    it { is_expected.to allow_value(http).for(:home_page_url) }
    it { is_expected.to allow_value(https).for(:home_page_url) }
    it { is_expected.not_to allow_value(ftp).for(:home_page_url) }

    it { is_expected.to allow_value(nil).for(:after_sign_out_path) }
    it { is_expected.to allow_value(http).for(:after_sign_out_path) }
    it { is_expected.to allow_value(https).for(:after_sign_out_path) }
    it { is_expected.not_to allow_value(ftp).for(:after_sign_out_path) }

    it { is_expected.to allow_value("dev.gitlab.com").for(:commit_email_hostname) }
    it { is_expected.not_to allow_value("@dev.gitlab").for(:commit_email_hostname) }

    describe 'default_artifacts_expire_in' do
      it 'sets an error if it cannot parse' do
        setting.update(default_artifacts_expire_in: 'a')

        expect_invalid
      end

      it 'sets an error if it is blank' do
        setting.update(default_artifacts_expire_in: ' ')

        expect_invalid
      end

      it 'sets the value if it is valid' do
        setting.update(default_artifacts_expire_in: '30 days')

        expect(setting).to be_valid
        expect(setting.default_artifacts_expire_in).to eq('30 days')
      end

      it 'sets the value if it is 0' do
        setting.update(default_artifacts_expire_in: '0')

        expect(setting).to be_valid
        expect(setting.default_artifacts_expire_in).to eq('0')
      end

      def expect_invalid
        expect(setting).to be_invalid
        expect(setting.errors.messages)
          .to have_key(:default_artifacts_expire_in)
      end
    end

    it { is_expected.to validate_presence_of(:max_attachment_size) }

    it do
      is_expected.to validate_numericality_of(:max_attachment_size)
        .only_integer
        .is_greater_than(0)
    end

    it do
      is_expected.to validate_numericality_of(:local_markdown_version)
        .only_integer
        .is_greater_than_or_equal_to(0)
        .is_less_than(65536)
    end

    context 'key restrictions' do
      it 'supports all key types' do
        expect(described_class::SUPPORTED_KEY_TYPES).to contain_exactly(:rsa, :dsa, :ecdsa, :ed25519)
      end

      it 'does not allow all key types to be disabled' do
        described_class::SUPPORTED_KEY_TYPES.each do |type|
          setting["#{type}_key_restriction"] = described_class::FORBIDDEN_KEY_VALUE
        end

        expect(setting).not_to be_valid
        expect(setting.errors.messages).to have_key(:allowed_key_types)
      end

      where(:type) do
        described_class::SUPPORTED_KEY_TYPES
      end

      with_them do
        let(:field) { :"#{type}_key_restriction" }

        it { is_expected.to validate_presence_of(field) }
        it { is_expected.to allow_value(*KeyRestrictionValidator.supported_key_restrictions(type)).for(field) }
        it { is_expected.not_to allow_value(128).for(field) }
      end
    end

    it_behaves_like 'an object with email-formated attributes', :admin_notification_email do
      subject { setting }
    end

    # Upgraded databases will have this sort of content
    context 'repository_storages is a String, not an Array' do
      before do
        described_class.where(id: setting.id).update_all(repository_storages: 'default')
      end

      it { expect(setting.repository_storages).to eq(['default']) }
    end

    context '#commit_email_hostname' do
      it 'returns configured gitlab hostname if commit_email_hostname is not defined' do
        setting.update(commit_email_hostname: nil)

        expect(setting.commit_email_hostname).to eq("users.noreply.#{Gitlab.config.gitlab.host}")
      end
    end

    context 'auto_devops_domain setting' do
      context 'when auto_devops_enabled? is true' do
        before do
          setting.update(auto_devops_enabled: true)
        end

        it 'can be blank' do
          setting.update(auto_devops_domain: '')

          expect(setting).to be_valid
        end

        context 'with a valid value' do
          before do
            setting.update(auto_devops_domain: 'domain.com')
          end

          it 'is valid' do
            expect(setting).to be_valid
          end
        end

        context 'with an invalid value' do
          before do
            setting.update(auto_devops_domain: 'definitelynotahostname')
          end

          it 'is invalid' do
            expect(setting).to be_invalid
          end
        end
      end
    end

    context 'repository storages' do
      before do
        storages = {
          'custom1' => 'tmp/tests/custom_repositories_1',
          'custom2' => 'tmp/tests/custom_repositories_2',
          'custom3' => 'tmp/tests/custom_repositories_3'

        }
        allow(Gitlab.config.repositories).to receive(:storages).and_return(storages)
      end

      describe 'inclusion' do
        it { is_expected.to allow_value('custom1').for(:repository_storages) }
        it { is_expected.to allow_value(%w(custom2 custom3)).for(:repository_storages) }
        it { is_expected.not_to allow_value('alternative').for(:repository_storages) }
        it { is_expected.not_to allow_value(%w(alternative custom1)).for(:repository_storages) }
      end

      describe 'presence' do
        it { is_expected.not_to allow_value([]).for(:repository_storages) }
        it { is_expected.not_to allow_value("").for(:repository_storages) }
        it { is_expected.not_to allow_value(nil).for(:repository_storages) }
      end

      describe '.pick_repository_storage' do
        it 'uses Array#sample to pick a random storage' do
          array = double('array', sample: 'random')
          expect(setting).to receive(:repository_storages).and_return(array)

          expect(setting.pick_repository_storage).to eq('random')
        end
      end
    end

    context 'housekeeping settings' do
      it { is_expected.not_to allow_value(0).for(:housekeeping_incremental_repack_period) }

      it 'wants the full repack period to be at least the incremental repack period' do
        subject.housekeeping_incremental_repack_period = 2
        subject.housekeeping_full_repack_period = 1

        expect(subject).not_to be_valid
      end

      it 'wants the gc period to be at least the full repack period' do
        subject.housekeeping_full_repack_period = 100
        subject.housekeeping_gc_period = 90

        expect(subject).not_to be_valid
      end

      it 'allows the same period for incremental repack and full repack, effectively skipping incremental repack' do
        subject.housekeeping_incremental_repack_period = 2
        subject.housekeeping_full_repack_period = 2

        expect(subject).to be_valid
      end

      it 'allows the same period for full repack and gc, effectively skipping full repack' do
        subject.housekeeping_full_repack_period = 100
        subject.housekeeping_gc_period = 100

        expect(subject).to be_valid
      end
    end

    context 'gitaly timeouts' do
      [:gitaly_timeout_default, :gitaly_timeout_medium, :gitaly_timeout_fast].each do |timeout_name|
        it do
          is_expected.to validate_presence_of(timeout_name)
          is_expected.to validate_numericality_of(timeout_name).only_integer
            .is_greater_than_or_equal_to(0)
        end
      end

      [:gitaly_timeout_medium, :gitaly_timeout_fast].each do |timeout_name|
        it "validates that #{timeout_name} is lower than timeout_default" do
          subject[:gitaly_timeout_default] = 50
          subject[timeout_name] = 100

          expect(subject).to be_invalid
        end
      end

      it 'accepts all timeouts equal' do
        subject.gitaly_timeout_default = 0
        subject.gitaly_timeout_medium = 0
        subject.gitaly_timeout_fast = 0

        expect(subject).to be_valid
      end

      it 'accepts timeouts in descending order' do
        subject.gitaly_timeout_default = 50
        subject.gitaly_timeout_medium = 30
        subject.gitaly_timeout_fast = 20

        expect(subject).to be_valid
      end

      it 'rejects timeouts in ascending order' do
        subject.gitaly_timeout_default = 20
        subject.gitaly_timeout_medium = 30
        subject.gitaly_timeout_fast = 50

        expect(subject).to be_invalid
      end

      it 'rejects medium timeout larger than default' do
        subject.gitaly_timeout_default = 30
        subject.gitaly_timeout_medium = 50
        subject.gitaly_timeout_fast = 20

        expect(subject).to be_invalid
      end

      it 'rejects medium timeout smaller than fast' do
        subject.gitaly_timeout_default = 30
        subject.gitaly_timeout_medium = 15
        subject.gitaly_timeout_fast = 20

        expect(subject).to be_invalid
      end
    end

    describe 'enforcing terms' do
      it 'requires the terms to present when enforcing users to accept' do
        subject.enforce_terms = true

        expect(subject).to be_invalid
      end

      it 'is valid when terms are created' do
        create(:term)
        subject.enforce_terms = true

        expect(subject).to be_valid
      end
    end
  end

  context 'restrict creating duplicates' do
    before do
      described_class.create_from_defaults
    end

    it 'raises an record creation violation if already created' do
      expect { described_class.create_from_defaults }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'setting Sentry DSNs' do
    context 'server DSN' do
      it 'strips leading and trailing whitespace' do
        subject.update(sentry_dsn: ' http://test ')

        expect(subject.sentry_dsn).to eq('http://test')
      end

      it 'handles nil values' do
        subject.update(sentry_dsn: nil)

        expect(subject.sentry_dsn).to be_nil
      end
    end

    context 'client-side DSN' do
      it 'strips leading and trailing whitespace' do
        subject.update(clientside_sentry_dsn: ' http://test ')

        expect(subject.clientside_sentry_dsn).to eq('http://test')
      end

      it 'handles nil values' do
        subject.update(clientside_sentry_dsn: nil)

        expect(subject.clientside_sentry_dsn).to be_nil
      end
    end
  end

  describe '#disabled_oauth_sign_in_sources=' do
    before do
      allow(Devise).to receive(:omniauth_providers).and_return([:github])
    end

    it 'removes unknown sources (as strings) from the array' do
      subject.disabled_oauth_sign_in_sources = %w[github test]

      expect(subject).to be_valid
      expect(subject.disabled_oauth_sign_in_sources).to eq ['github']
    end

    it 'removes unknown sources (as symbols) from the array' do
      subject.disabled_oauth_sign_in_sources = %i[github test]

      expect(subject).to be_valid
      expect(subject.disabled_oauth_sign_in_sources).to eq ['github']
    end

    it 'ignores nil' do
      subject.disabled_oauth_sign_in_sources = nil

      expect(subject).to be_valid
      expect(subject.disabled_oauth_sign_in_sources).to be_empty
    end
  end

  context 'restricted signup domains' do
    it 'sets single domain' do
      setting.domain_whitelist_raw = 'example.com'
      expect(setting.domain_whitelist).to eq(['example.com'])
    end

    it 'sets multiple domains with spaces' do
      setting.domain_whitelist_raw = 'example.com *.example.com'
      expect(setting.domain_whitelist).to eq(['example.com', '*.example.com'])
    end

    it 'sets multiple domains with newlines and a space' do
      setting.domain_whitelist_raw = "example.com\n *.example.com"
      expect(setting.domain_whitelist).to eq(['example.com', '*.example.com'])
    end

    it 'sets multiple domains with commas' do
      setting.domain_whitelist_raw = "example.com, *.example.com"
      expect(setting.domain_whitelist).to eq(['example.com', '*.example.com'])
    end
  end

  context 'blacklisted signup domains' do
    it 'sets single domain' do
      setting.domain_blacklist_raw = 'example.com'
      expect(setting.domain_blacklist).to contain_exactly('example.com')
    end

    it 'sets multiple domains with spaces' do
      setting.domain_blacklist_raw = 'example.com *.example.com'
      expect(setting.domain_blacklist).to contain_exactly('example.com', '*.example.com')
    end

    it 'sets multiple domains with newlines and a space' do
      setting.domain_blacklist_raw = "example.com\n *.example.com"
      expect(setting.domain_blacklist).to contain_exactly('example.com', '*.example.com')
    end

    it 'sets multiple domains with commas' do
      setting.domain_blacklist_raw = "example.com, *.example.com"
      expect(setting.domain_blacklist).to contain_exactly('example.com', '*.example.com')
    end

    it 'sets multiple domains with semicolon' do
      setting.domain_blacklist_raw = "example.com; *.example.com"
      expect(setting.domain_blacklist).to contain_exactly('example.com', '*.example.com')
    end

    it 'sets multiple domains with mixture of everything' do
      setting.domain_blacklist_raw = "example.com; *.example.com\n test.com\sblock.com   yes.com"
      expect(setting.domain_blacklist).to contain_exactly('example.com', '*.example.com', 'test.com', 'block.com', 'yes.com')
    end

    it 'sets multiple domain with file' do
      setting.domain_blacklist_file = File.open(Rails.root.join('spec/fixtures/', 'domain_blacklist.txt'))
      expect(setting.domain_blacklist).to contain_exactly('example.com', 'test.com', 'foo.bar')
    end
  end

  describe 'performance bar settings' do
    describe 'performance_bar_allowed_group' do
      context 'with no performance_bar_allowed_group_id saved' do
        it 'returns nil' do
          expect(setting.performance_bar_allowed_group).to be_nil
        end
      end

      context 'with a performance_bar_allowed_group_id saved' do
        let(:group) { create(:group) }

        before do
          setting.update!(performance_bar_allowed_group_id: group.id)
        end

        it 'returns the group' do
          expect(setting.reload.performance_bar_allowed_group).to eq(group)
        end
      end
    end

    describe 'performance_bar_enabled' do
      context 'with the Performance Bar is enabled' do
        let(:group) { create(:group) }

        before do
          setting.update!(performance_bar_allowed_group_id: group.id)
        end

        it 'returns true' do
          expect(setting.reload.performance_bar_enabled).to be_truthy
        end
      end
    end
  end

  describe 'usage ping settings' do
    context 'when the usage ping is disabled in gitlab.yml' do
      before do
        allow(Settings.gitlab).to receive(:usage_ping_enabled).and_return(false)
      end

      it 'does not allow the usage ping to be configured' do
        expect(setting.usage_ping_can_be_configured?).to be_falsey
      end

      context 'when the usage ping is disabled in the DB' do
        before do
          setting.usage_ping_enabled = false
        end

        it 'returns false for usage_ping_enabled' do
          expect(setting.usage_ping_enabled).to be_falsey
        end
      end

      context 'when the usage ping is enabled in the DB' do
        before do
          setting.usage_ping_enabled = true
        end

        it 'returns false for usage_ping_enabled' do
          expect(setting.usage_ping_enabled).to be_falsey
        end
      end
    end

    context 'when the usage ping is enabled in gitlab.yml' do
      before do
        allow(Settings.gitlab).to receive(:usage_ping_enabled).and_return(true)
      end

      it 'allows the usage ping to be configured' do
        expect(setting.usage_ping_can_be_configured?).to be_truthy
      end

      context 'when the usage ping is disabled in the DB' do
        before do
          setting.usage_ping_enabled = false
        end

        it 'returns false for usage_ping_enabled' do
          expect(setting.usage_ping_enabled).to be_falsey
        end
      end

      context 'when the usage ping is enabled in the DB' do
        before do
          setting.usage_ping_enabled = true
        end

        it 'returns true for usage_ping_enabled' do
          expect(setting.usage_ping_enabled).to be_truthy
        end
      end
    end
  end

  describe '#allowed_key_types' do
    it 'includes all key types by default' do
      expect(setting.allowed_key_types).to contain_exactly(*described_class::SUPPORTED_KEY_TYPES)
    end

    it 'excludes disabled key types' do
      expect(setting.allowed_key_types).to include(:ed25519)

      setting.ed25519_key_restriction = described_class::FORBIDDEN_KEY_VALUE

      expect(setting.allowed_key_types).not_to include(:ed25519)
    end
  end

  describe '#key_restriction_for' do
    it 'returns the restriction value for recognised types' do
      setting.rsa_key_restriction = 1024

      expect(setting.key_restriction_for(:rsa)).to eq(1024)
    end

    it 'allows types to be passed as a string' do
      setting.rsa_key_restriction = 1024

      expect(setting.key_restriction_for('rsa')).to eq(1024)
    end

    it 'returns forbidden for unrecognised type' do
      expect(setting.key_restriction_for(:foo)).to eq(described_class::FORBIDDEN_KEY_VALUE)
    end
  end

  describe '#allow_signup?' do
    it 'returns true' do
      expect(setting.allow_signup?).to be_truthy
    end

    it 'returns false if signup is disabled' do
      allow(setting).to receive(:signup_enabled?).and_return(false)

      expect(setting.allow_signup?).to be_falsey
    end

    it 'returns false if password authentication is disabled for the web interface' do
      allow(setting).to receive(:password_authentication_enabled_for_web?).and_return(false)

      expect(setting.allow_signup?).to be_falsey
    end
  end

  describe '#user_default_internal_regex_enabled?' do
    using RSpec::Parameterized::TableSyntax

    where(:user_default_external, :user_default_internal_regex, :result) do
      false | nil                        | false
      false | ''                         | false
      false | '^(?:(?!\.ext@).)*$\r?\n?' | false
      true  | ''                         | false
      true  | nil                        | false
      true  | '^(?:(?!\.ext@).)*$\r?\n?' | true
    end

    with_them do
      before do
        setting.update(user_default_external: user_default_external)
        setting.update(user_default_internal_regex: user_default_internal_regex)
      end

      subject { setting.user_default_internal_regex_enabled? }

      it { is_expected.to eq(result) }
    end
  end

  context 'diff limit settings' do
    describe '#diff_max_patch_bytes' do
      context 'validations' do
        it { is_expected.to validate_presence_of(:diff_max_patch_bytes) }

        it do
          is_expected.to validate_numericality_of(:diff_max_patch_bytes)
          .only_integer
          .is_greater_than_or_equal_to(Gitlab::Git::Diff::DEFAULT_MAX_PATCH_BYTES)
          .is_less_than_or_equal_to(Gitlab::Git::Diff::MAX_PATCH_BYTES_UPPER_BOUND)
        end
      end
    end
  end

  describe '#archive_builds_older_than' do
    subject { setting.archive_builds_older_than }

    context 'when the archive_builds_in_seconds is set' do
      before do
        setting.archive_builds_in_seconds = 3600
      end

      it { is_expected.to be_within(1.minute).of(1.hour.ago) }
    end

    context 'when the archive_builds_in_seconds is set' do
      before do
        setting.archive_builds_in_seconds = nil
      end

      it { is_expected.to be_nil }
    end
  end
end
