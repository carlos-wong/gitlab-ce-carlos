# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Feature, stub_feature_flags: false do
  include StubVersion

  before do
    # reset Flipper AR-engine
    Feature.reset
    skip_feature_flags_yaml_validation
  end

  describe '.feature_flags_available?' do
    it 'returns false on connection error' do
      expect(ActiveRecord::Base.connection).to receive(:active?).and_raise(PG::ConnectionBad) # rubocop:disable Database/MultipleDatabases

      expect(described_class.feature_flags_available?).to eq(false)
    end

    it 'returns false when connection is not active' do
      expect(ActiveRecord::Base.connection).to receive(:active?).and_return(false) # rubocop:disable Database/MultipleDatabases

      expect(described_class.feature_flags_available?).to eq(false)
    end

    it 'returns false when the flipper table does not exist' do
      expect(Feature::FlipperFeature).to receive(:table_exists?).and_return(false)

      expect(described_class.feature_flags_available?).to eq(false)
    end

    it 'returns false on NoDatabaseError' do
      expect(Feature::FlipperFeature).to receive(:table_exists?).and_raise(ActiveRecord::NoDatabaseError)

      expect(described_class.feature_flags_available?).to eq(false)
    end
  end

  describe '.get' do
    let(:feature) { double(:feature) }
    let(:key) { 'my_feature' }

    it 'returns the Flipper feature' do
      expect_any_instance_of(Flipper::DSL).to receive(:feature).with(key)
        .and_return(feature)

      expect(described_class.get(key)).to eq(feature)
    end
  end

  describe '.persisted_names' do
    it 'returns the names of the persisted features' do
      Feature.enable('foo')

      expect(described_class.persisted_names).to contain_exactly('foo')
    end

    it 'returns an empty Array when no features are presisted' do
      expect(described_class.persisted_names).to be_empty
    end

    it 'caches the feature names when request store is active',
      :request_store, :use_clean_rails_memory_store_caching do
      Feature.enable('foo')

      expect(Gitlab::ProcessMemoryCache.cache_backend)
        .to receive(:fetch)
        .once
        .with('flipper/v1/features', { expires_in: 1.minute })
        .and_call_original

      2.times do
        expect(described_class.persisted_names).to contain_exactly('foo')
      end
    end

    it 'fetches all flags once in a single query', :request_store do
      Feature.enable('foo1')
      Feature.enable('foo2')

      queries = ActiveRecord::QueryRecorder.new(skip_cached: false) do
        expect(described_class.persisted_names).to contain_exactly('foo1', 'foo2')

        RequestStore.clear!

        expect(described_class.persisted_names).to contain_exactly('foo1', 'foo2')
      end

      expect(queries.count).to eq(1)
    end
  end

  describe '.persisted_name?' do
    context 'when the feature is persisted' do
      it 'returns true when feature name is a string' do
        Feature.enable('foo')

        expect(described_class.persisted_name?('foo')).to eq(true)
      end

      it 'returns true when feature name is a symbol' do
        Feature.enable('foo')

        expect(described_class.persisted_name?(:foo)).to eq(true)
      end
    end

    context 'when the feature is not persisted' do
      it 'returns false when feature name is a string' do
        expect(described_class.persisted_name?('foo')).to eq(false)
      end

      it 'returns false when feature name is a symbol' do
        expect(described_class.persisted_name?(:bar)).to eq(false)
      end
    end
  end

  describe '.all' do
    let(:features) { Set.new }

    it 'returns the Flipper features as an array' do
      expect_any_instance_of(Flipper::DSL).to receive(:features)
        .and_return(features)

      expect(described_class.all).to eq(features.to_a)
    end
  end

  describe '.flipper' do
    context 'when request store is inactive' do
      it 'memoizes the Flipper instance but does not not enable Flipper memoization' do
        expect(Flipper).to receive(:new).once.and_call_original

        2.times do
          described_class.flipper
        end

        expect(described_class.flipper.adapter.memoizing?).to eq(false)
      end
    end

    context 'when request store is active', :request_store do
      it 'memoizes the Flipper instance' do
        expect(Flipper).to receive(:new).once.and_call_original

        described_class.flipper
        described_class.instance_variable_set(:@flipper, nil)
        described_class.flipper

        expect(described_class.flipper.adapter.memoizing?).to eq(true)
      end
    end
  end

  describe '.enabled?' do
    before do
      allow(Feature).to receive(:log_feature_flag_states?).and_return(false)

      stub_feature_flag_definition(:disabled_feature_flag)
      stub_feature_flag_definition(:enabled_feature_flag, default_enabled: true)
    end

    context 'when self-recursive' do
      before do
        allow(Feature).to receive(:with_feature).and_wrap_original do |original, name, &block|
          original.call(name) do |ff|
            Feature.enabled?(name)
            block.call(ff)
          end
        end
      end

      it 'returns the default value' do
        expect(described_class.enabled?(:enabled_feature_flag)).to eq true
      end

      it 'detects self recursion' do
        expect(Gitlab::ErrorTracking)
          .to receive(:track_exception)
          .with(have_attributes(message: 'self recursion'), { stack: [:enabled_feature_flag] })

        described_class.enabled?(:enabled_feature_flag)
      end
    end

    context 'when deeply recursive' do
      before do
        allow(Feature).to receive(:with_feature).and_wrap_original do |original, name, &block|
          original.call(name) do |ff|
            Feature.enabled?(:"deeper_#{name}", type: :undefined, default_enabled_if_undefined: true)
            block.call(ff)
          end
        end
      end

      it 'detects deep recursion' do
        expect(Gitlab::ErrorTracking)
          .to receive(:track_exception)
          .with(have_attributes(message: 'deep recursion'), stack: have_attributes(size: be > 10))

        described_class.enabled?(:enabled_feature_flag)
      end
    end

    it 'returns false (and tracks / raises exception for dev) for undefined feature' do
      expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)

      expect(described_class.enabled?(:some_random_feature_flag)).to be_falsey
    end

    it 'returns false for undefined feature with default_enabled_if_undefined: false' do
      expect(described_class.enabled?(:some_random_feature_flag, default_enabled_if_undefined: false)).to be_falsey
    end

    it 'returns true for undefined feature with default_enabled_if_undefined: true' do
      expect(described_class.enabled?(:some_random_feature_flag, default_enabled_if_undefined: true)).to be_truthy
    end

    it 'returns false for existing disabled feature in the database' do
      described_class.disable(:disabled_feature_flag)

      expect(described_class.enabled?(:disabled_feature_flag)).to be_falsey
    end

    it 'returns true for existing enabled feature in the database' do
      described_class.enable(:enabled_feature_flag)

      expect(described_class.enabled?(:enabled_feature_flag)).to be_truthy
    end

    it { expect(described_class.send(:l1_cache_backend)).to eq(Gitlab::ProcessMemoryCache.cache_backend) }
    it { expect(described_class.send(:l2_cache_backend)).to eq(Rails.cache) }

    it 'caches the status in L1 and L2 caches',
       :request_store, :use_clean_rails_memory_store_caching do
      described_class.enable(:disabled_feature_flag)
      flipper_key = "flipper/v1/feature/disabled_feature_flag"

      expect(described_class.send(:l2_cache_backend))
        .to receive(:fetch)
        .once
        .with(flipper_key, { expires_in: 1.hour })
        .and_call_original

      expect(described_class.send(:l1_cache_backend))
        .to receive(:fetch)
        .once
        .with(flipper_key, { expires_in: 1.minute })
        .and_call_original

      2.times do
        expect(described_class.enabled?(:disabled_feature_flag)).to be_truthy
      end
    end

    it 'returns the default value when the database does not exist' do
      fake_default = double('fake default')
      expect(ActiveRecord::Base).to receive(:connection) { raise ActiveRecord::NoDatabaseError, "No database" }

      expect(described_class.enabled?(:a_feature, default_enabled_if_undefined: fake_default)).to eq(fake_default)
    end

    context 'logging is enabled', :request_store do
      before do
        allow(Feature).to receive(:log_feature_flag_states?).and_call_original

        stub_feature_flag_definition(:enabled_feature_flag, log_state_changes: true)

        described_class.enable(:feature_flag_state_logs)
        described_class.enable(:enabled_feature_flag)
        described_class.enabled?(:enabled_feature_flag)
      end

      it 'does not log feature_flag_state_logs' do
        expect(described_class.logged_states).not_to have_key("feature_flag_state_logs")
      end

      it 'logs other feature flags' do
        expect(described_class.logged_states).to have_key(:enabled_feature_flag)
        expect(described_class.logged_states[:enabled_feature_flag]).to be_truthy
      end
    end

    context 'cached feature flag', :request_store do
      before do
        described_class.send(:flipper).memoize = false
        described_class.enabled?(:disabled_feature_flag)
      end

      it 'caches the status in L1 cache for the first minute' do
        expect do
          expect(described_class.send(:l1_cache_backend)).to receive(:fetch).once.and_call_original
          expect(described_class.send(:l2_cache_backend)).not_to receive(:fetch)
          expect(described_class.enabled?(:disabled_feature_flag)).to be_truthy
        end.not_to exceed_query_limit(0)
      end

      it 'caches the status in L2 cache after 2 minutes' do
        travel_to 2.minutes.from_now do
          expect do
            expect(described_class.send(:l1_cache_backend)).to receive(:fetch).once.and_call_original
            expect(described_class.send(:l2_cache_backend)).to receive(:fetch).once.and_call_original
            expect(described_class.enabled?(:disabled_feature_flag)).to be_truthy
          end.not_to exceed_query_limit(0)
        end
      end

      it 'fetches the status after an hour' do
        travel_to 61.minutes.from_now do
          expect do
            expect(described_class.send(:l1_cache_backend)).to receive(:fetch).once.and_call_original
            expect(described_class.send(:l2_cache_backend)).to receive(:fetch).once.and_call_original
            expect(described_class.enabled?(:disabled_feature_flag)).to be_truthy
          end.not_to exceed_query_limit(1)
        end
      end
    end

    context 'with an individual actor' do
      let(:actor) { stub_feature_flag_gate('CustomActor:5') }
      let(:another_actor) { stub_feature_flag_gate('CustomActor:10') }

      before do
        described_class.enable(:enabled_feature_flag, actor)
      end

      it 'returns true when same actor is informed' do
        expect(described_class.enabled?(:enabled_feature_flag, actor)).to be_truthy
      end

      it 'returns false when different actor is informed' do
        expect(described_class.enabled?(:enabled_feature_flag, another_actor)).to be_falsey
      end

      it 'returns false when no actor is informed' do
        expect(described_class.enabled?(:enabled_feature_flag)).to be_falsey
      end
    end

    context 'with invalid actor' do
      let(:actor) { double('invalid actor') }

      context 'when is dev_or_test_env' do
        it 'does raise exception' do
          expect { described_class.enabled?(:enabled_feature_flag, actor) }
            .to raise_error /needs to include `FeatureGate` or implement `flipper_id`/
        end
      end
    end

    context 'validates usage of feature flag with YAML definition' do
      let(:definition) do
        Feature::Definition.new('development/my_feature_flag.yml',
          name: 'my_feature_flag',
          type: 'development',
          default_enabled: default_enabled
        ).tap(&:validate!)
      end

      let(:default_enabled) { false }

      before do
        stub_env('LAZILY_CREATE_FEATURE_FLAG', '0')

        allow(Feature::Definition).to receive(:valid_usage!).and_call_original
        allow(Feature::Definition).to receive(:definitions) do
          { definition.key => definition }
        end
      end

      it 'when usage is correct' do
        expect { described_class.enabled?(:my_feature_flag) }.not_to raise_error
      end

      it 'when invalid type is used' do
        expect { described_class.enabled?(:my_feature_flag, type: :ops) }
          .to raise_error(/The `type:` of/)
      end

      context 'when default_enabled: is false in the YAML definition' do
        it 'reads the default from the YAML definition' do
          expect(described_class.enabled?(:my_feature_flag)).to eq(default_enabled)
        end
      end

      context 'when default_enabled: is true in the YAML definition' do
        let(:default_enabled) { true }

        it 'reads the default from the YAML definition' do
          expect(described_class.enabled?(:my_feature_flag)).to eq(true)
        end

        context 'and feature has been disabled' do
          before do
            described_class.disable(:my_feature_flag)
          end

          it 'is not enabled' do
            expect(described_class.enabled?(:my_feature_flag)).to eq(false)
          end
        end

        context 'with a cached value and the YAML definition is changed thereafter' do
          before do
            described_class.enabled?(:my_feature_flag)
          end

          it 'reads new default value' do
            allow(definition).to receive(:default_enabled).and_return(true)

            expect(described_class.enabled?(:my_feature_flag)).to eq(true)
          end
        end

        context 'when YAML definition does not exist for an optional type' do
          let(:optional_type) { described_class::Shared::TYPES.find { |name, attrs| attrs[:optional] }.first }

          context 'when in dev or test environment' do
            it 'raises an error for dev' do
              expect { described_class.enabled?(:non_existent_flag, type: optional_type) }
                .to raise_error(
                  Feature::InvalidFeatureFlagError,
                  "The feature flag YAML definition for 'non_existent_flag' does not exist")
            end
          end

          context 'when in production' do
            before do
              allow(Gitlab::ErrorTracking).to receive(:should_raise_for_dev?).and_return(false)
            end

            context 'when database exists' do
              before do
                allow(ApplicationRecord.database).to receive(:exists?).and_return(true)
              end

              it 'checks the persisted status and returns false' do
                expect(described_class).to receive(:with_feature).with(:non_existent_flag).and_call_original

                expect(described_class.enabled?(:non_existent_flag, type: optional_type)).to eq(false)
              end
            end

            context 'when database does not exist' do
              before do
                allow(ApplicationRecord.database).to receive(:exists?).and_return(false)
              end

              it 'returns false without checking the status in the database' do
                expect(described_class).not_to receive(:get)

                expect(described_class.enabled?(:non_existent_flag, type: optional_type)).to eq(false)
              end
            end
          end
        end
      end
    end
  end

  describe '.disable?' do
    it 'returns true (and tracks / raises exception for dev) for undefined feature' do
      expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)

      expect(described_class.disabled?(:some_random_feature_flag)).to be_truthy
    end

    it 'returns true for undefined feature with default_enabled_if_undefined: false' do
      expect(described_class.disabled?(:some_random_feature_flag, default_enabled_if_undefined: false)).to be_truthy
    end

    it 'returns false for undefined feature with default_enabled_if_undefined: true' do
      expect(described_class.disabled?(:some_random_feature_flag, default_enabled_if_undefined: true)).to be_falsey
    end

    it 'returns true for existing disabled feature in the database' do
      stub_feature_flag_definition(:disabled_feature_flag)
      described_class.disable(:disabled_feature_flag)

      expect(described_class.disabled?(:disabled_feature_flag)).to be_truthy
    end

    it 'returns false for existing enabled feature in the database' do
      stub_feature_flag_definition(:enabled_feature_flag)
      described_class.enable(:enabled_feature_flag)

      expect(described_class.disabled?(:enabled_feature_flag)).to be_falsey
    end
  end

  shared_examples_for 'logging' do
    let(:expected_action) { }
    let(:expected_extra) { }

    it 'logs the event' do
      expect(Feature.logger).to receive(:info).with(key: key, action: expected_action, **expected_extra)

      subject
    end
  end

  describe '.enable' do
    subject { described_class.enable(key, thing) }

    let(:key) { :awesome_feature }
    let(:thing) { true }

    it_behaves_like 'logging' do
      let(:expected_action) { :enable }
      let(:expected_extra) { { "extra.thing" => "true" } }
    end

    # This is documented to return true, modify doc/administration/feature_flags.md if it changes
    it 'returns true' do
      expect(subject).to be true
    end

    context 'when thing is an actor' do
      let(:thing) { create(:project) }

      it_behaves_like 'logging' do
        let(:expected_action) { :enable }
        let(:expected_extra) { { "extra.thing" => "#{thing.flipper_id}" } }
      end
    end
  end

  describe '.disable' do
    subject { described_class.disable(key, thing) }

    let(:key) { :awesome_feature }
    let(:thing) { false }

    it_behaves_like 'logging' do
      let(:expected_action) { :disable }
      let(:expected_extra) { { "extra.thing" => "false" } }
    end

    # This is documented to return true, modify doc/administration/feature_flags.md if it changes
    it 'returns true' do
      expect(subject).to be true
    end

    context 'when thing is an actor' do
      let(:thing) { create(:project) }

      it_behaves_like 'logging' do
        let(:expected_action) { :disable }
        let(:expected_extra) { { "extra.thing" => "#{thing.flipper_id}" } }
      end
    end
  end

  describe '.enable_percentage_of_time' do
    subject { described_class.enable_percentage_of_time(key, percentage) }

    let(:key) { :awesome_feature }
    let(:percentage) { 50 }

    it_behaves_like 'logging' do
      let(:expected_action) { :enable_percentage_of_time }
      let(:expected_extra) { { "extra.percentage" => "#{percentage}" } }
    end
  end

  describe '.disable_percentage_of_time' do
    subject { described_class.disable_percentage_of_time(key) }

    let(:key) { :awesome_feature }

    it_behaves_like 'logging' do
      let(:expected_action) { :disable_percentage_of_time }
      let(:expected_extra) { {} }
    end
  end

  describe '.enable_percentage_of_actors' do
    subject { described_class.enable_percentage_of_actors(key, percentage) }

    let(:key) { :awesome_feature }
    let(:percentage) { 50 }

    it_behaves_like 'logging' do
      let(:expected_action) { :enable_percentage_of_actors }
      let(:expected_extra) { { "extra.percentage" => "#{percentage}" } }
    end
  end

  describe '.disable_percentage_of_actors' do
    subject { described_class.disable_percentage_of_actors(key) }

    let(:key) { :awesome_feature }

    it_behaves_like 'logging' do
      let(:expected_action) { :disable_percentage_of_actors }
      let(:expected_extra) { {} }
    end
  end

  describe '.remove' do
    subject { described_class.remove(key) }

    let(:key) { :awesome_feature }

    before do
      described_class.enable(key)
    end

    it_behaves_like 'logging' do
      let(:expected_action) { :remove }
      let(:expected_extra) { {} }
    end

    context 'for a non-persisted feature' do
      it 'returns nil' do
        expect(described_class.remove(:non_persisted_feature_flag)).to be_nil
      end
    end

    context 'for a persisted feature' do
      it 'returns true' do
        described_class.enable(:persisted_feature_flag)

        expect(described_class.remove(:persisted_feature_flag)).to be_truthy
      end
    end
  end

  describe '.log_feature_flag_states?' do
    let(:log_state_changes) { false }
    let(:milestone) { "0.0" }
    let(:flag_name) { :some_flag }
    let(:flag_type) { 'development' }

    before do
      Feature.enable(:feature_flag_state_logs)
      Feature.enable(:some_flag)

      allow(Feature).to receive(:log_feature_flag_states?).and_return(false)
      allow(Feature).to receive(:log_feature_flag_states?).with(:feature_flag_state_logs).and_call_original
      allow(Feature).to receive(:log_feature_flag_states?).with(:some_flag).and_call_original

      stub_feature_flag_definition(flag_name,
        type: flag_type,
        milestone: milestone,
        log_state_changes: log_state_changes)
    end

    subject { described_class.log_feature_flag_states?(flag_name) }

    context 'when flag is feature_flag_state_logs' do
      let(:milestone) { "14.6" }
      let(:flag_name) { :feature_flag_state_logs }
      let(:flag_type) { 'ops' }
      let(:log_state_changes) { true }

      it { is_expected.to be_falsey }
    end

    context 'when flag is old' do
      it { is_expected.to be_falsey }
    end

    context 'when flag is old while log_state_changes is not present ' do
      let(:log_state_changes) { nil }

      it { is_expected.to be_falsey }
    end

    context 'when flag is old but log_state_changes is true' do
      let(:log_state_changes) { true }

      it { is_expected.to be_truthy }
    end

    context 'when flag is new and not feature_flag_state_logs' do
      let(:milestone) { "14.6" }

      before do
        stub_version('14.5.123', 'deadbeef')
      end

      it { is_expected.to be_truthy }
    end

    context 'when milestone is nil' do
      let(:milestone) { nil }

      it { is_expected.to be_falsey }
    end
  end

  context 'caching with stale reads from the database', :use_clean_rails_redis_caching, :request_store, :aggregate_failures do
    let(:actor) { stub_feature_flag_gate('CustomActor:5') }
    let(:another_actor) { stub_feature_flag_gate('CustomActor:10') }

    # This is a bit unpleasant. For these tests we want to simulate stale reads
    # from the database (due to database load balancing). A simple way to do
    # that is to stub the response on the adapter Flipper uses for reading from
    # the database. However, there isn't a convenient API for this. We know that
    # the ActiveRecord adapter is always at the 'bottom' of the chain, so we can
    # find it that way.
    let(:active_record_adapter) do
      adapter = described_class.flipper

      loop do
        break adapter unless adapter.instance_variable_get(:@adapter)

        adapter = adapter.instance_variable_get(:@adapter)
      end
    end

    it 'gives the correct value when enabling for an additional actor' do
      described_class.enable(:enabled_feature_flag, actor)
      initial_gate_values = active_record_adapter.get(described_class.get(:enabled_feature_flag))

      # This should only be enabled for `actor`
      expect(described_class.enabled?(:enabled_feature_flag, actor)).to be(true)
      expect(described_class.enabled?(:enabled_feature_flag, another_actor)).to be(false)
      expect(described_class.enabled?(:enabled_feature_flag)).to be(false)

      # Enable for `another_actor` and simulate a stale read
      described_class.enable(:enabled_feature_flag, another_actor)
      allow(active_record_adapter).to receive(:get).once.and_return(initial_gate_values)

      # Should read from the cache and be enabled for both of these actors
      expect(described_class.enabled?(:enabled_feature_flag, actor)).to be(true)
      expect(described_class.enabled?(:enabled_feature_flag, another_actor)).to be(true)
      expect(described_class.enabled?(:enabled_feature_flag)).to be(false)
    end

    it 'gives the correct value when enabling for percentage of time' do
      described_class.enable_percentage_of_time(:enabled_feature_flag, 10)
      initial_gate_values = active_record_adapter.get(described_class.get(:enabled_feature_flag))

      # Test against `gate_values` directly as otherwise it would be non-determistic
      expect(described_class.get(:enabled_feature_flag).gate_values.percentage_of_time).to eq(10)

      # Enable 50% of time and simulate a stale read
      described_class.enable_percentage_of_time(:enabled_feature_flag, 50)
      allow(active_record_adapter).to receive(:get).once.and_return(initial_gate_values)

      # Should read from the cache and be enabled 50% of the time
      expect(described_class.get(:enabled_feature_flag).gate_values.percentage_of_time).to eq(50)
    end

    it 'gives the correct value when disabling the flag' do
      described_class.enable(:enabled_feature_flag, actor)
      described_class.enable(:enabled_feature_flag, another_actor)
      initial_gate_values = active_record_adapter.get(described_class.get(:enabled_feature_flag))

      # This be enabled for `actor` and `another_actor`
      expect(described_class.enabled?(:enabled_feature_flag, actor)).to be(true)
      expect(described_class.enabled?(:enabled_feature_flag, another_actor)).to be(true)
      expect(described_class.enabled?(:enabled_feature_flag)).to be(false)

      # Disable for `another_actor` and simulate a stale read
      described_class.disable(:enabled_feature_flag, another_actor)
      allow(active_record_adapter).to receive(:get).once.and_return(initial_gate_values)

      # Should read from the cache and be enabled only for `actor`
      expect(described_class.enabled?(:enabled_feature_flag, actor)).to be(true)
      expect(described_class.enabled?(:enabled_feature_flag, another_actor)).to be(false)
      expect(described_class.enabled?(:enabled_feature_flag)).to be(false)
    end

    it 'gives the correct value when deleting the flag' do
      described_class.enable(:enabled_feature_flag, actor)
      initial_gate_values = active_record_adapter.get(described_class.get(:enabled_feature_flag))

      # This should only be enabled for `actor`
      expect(described_class.enabled?(:enabled_feature_flag, actor)).to be(true)
      expect(described_class.enabled?(:enabled_feature_flag)).to be(false)

      # Remove and simulate a stale read
      described_class.remove(:enabled_feature_flag)
      allow(active_record_adapter).to receive(:get).once.and_return(initial_gate_values)

      # Should read from the cache and be disabled everywhere
      expect(described_class.enabled?(:enabled_feature_flag, actor)).to be(false)
      expect(described_class.enabled?(:enabled_feature_flag)).to be(false)
    end
  end

  describe Feature::Target do
    describe '#targets' do
      let(:project) { create(:project) }
      let(:group) { create(:group) }
      let(:user_name) { project.first_owner.username }

      subject { described_class.new(user: user_name, project: project.full_path, group: group.full_path) }

      it 'returns all found targets' do
        expect(subject.targets).to be_an(Array)
        expect(subject.targets).to eq([project.first_owner, project, group])
      end
    end
  end
end
