# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Gitlab::Tracking do
  include StubENV

  before do
    stub_application_setting(snowplow_enabled: true)
    stub_application_setting(snowplow_collector_hostname: 'gitfoo.com')
    stub_application_setting(snowplow_cookie_domain: '.gitfoo.com')
    stub_application_setting(snowplow_app_id: '_abc123_')

    described_class.instance_variable_set("@snowplow", nil)
  end

  after do
    described_class.instance_variable_set("@snowplow", nil)
  end

  describe '.options' do
    shared_examples 'delegates to destination' do |klass|
      before do
        allow_next_instance_of(klass) do |instance|
          allow(instance).to receive(:options).and_call_original
        end
      end

      it "delegates to #{klass} destination" do
        expect_next_instance_of(klass) do |instance|
          expect(instance).to receive(:options)
        end

        subject.options(nil)
      end
    end

    context 'when destination is Snowplow' do
      it_behaves_like 'delegates to destination', Gitlab::Tracking::Destinations::Snowplow

      it 'returns useful client options' do
        expected_fields = {
          namespace: 'gl',
          hostname: 'gitfoo.com',
          cookieDomain: '.gitfoo.com',
          appId: '_abc123_',
          formTracking: true,
          linkClickTracking: true
        }

        expect(subject.options(nil)).to match(expected_fields)
      end
    end

    context 'when destination is SnowplowMicro' do
      before do
        stub_env('SNOWPLOW_MICRO_ENABLE', '1')
        allow(Rails.env).to receive(:development?).and_return(true)
      end

      it_behaves_like 'delegates to destination', Gitlab::Tracking::Destinations::SnowplowMicro

      it 'returns useful client options' do
        expected_fields = {
          namespace: 'gl',
          hostname: 'localhost:9090',
          cookieDomain: '.gitlab.com',
          appId: '_abc123_',
          protocol: 'http',
          port: 9090,
          forceSecureTracker: false,
          formTracking: true,
          linkClickTracking: true
        }

        expect(subject.options(nil)).to match(expected_fields)
      end
    end

    it 'when feature flag is disabled' do
      stub_feature_flags(additional_snowplow_tracking: false)

      expect(subject.options(nil)).to include(
        formTracking: false,
        linkClickTracking: false
      )
    end
  end

  describe '.event' do
    let(:namespace) { create(:namespace) }

    shared_examples 'delegates to destination' do |klass|
      before do
        allow_any_instance_of(Gitlab::Tracking::Destinations::Snowplow).to receive(:event)
      end

      it "delegates to #{klass} destination" do
        other_context = double(:context)

        project = build_stubbed(:project)
        user = build_stubbed(:user)

        expect(Gitlab::Tracking::StandardContext)
          .to receive(:new)
          .with(project: project, user: user, namespace: namespace, extra_key_1: 'extra value 1', extra_key_2: 'extra value 2')
          .and_call_original

        expect_any_instance_of(klass).to receive(:event) do |_, category, action, args|
          expect(category).to eq('category')
          expect(action).to eq('action')
          expect(args[:label]).to eq('label')
          expect(args[:property]).to eq('property')
          expect(args[:value]).to eq(1.5)
          expect(args[:context].length).to eq(2)
          expect(args[:context].first.to_json[:schema]).to eq(Gitlab::Tracking::StandardContext::GITLAB_STANDARD_SCHEMA_URL)
          expect(args[:context].last).to eq(other_context)
        end

        described_class.event('category', 'action', label: 'label', property: 'property', value: 1.5,
                              context: [other_context], project: project, user: user, namespace: namespace,
                              extra_key_1: 'extra value 1', extra_key_2: 'extra value 2')
      end
    end

    context 'when destination is Snowplow' do
      before do
        stub_env('SNOWPLOW_MICRO_ENABLE', '0')
        allow(Rails.env).to receive(:development?).and_return(true)
      end

      it_behaves_like 'delegates to destination', Gitlab::Tracking::Destinations::Snowplow
    end

    context 'when destination is SnowplowMicro' do
      before do
        stub_env('SNOWPLOW_MICRO_ENABLE', '1')
        allow(Rails.env).to receive(:development?).and_return(true)
      end

      it_behaves_like 'delegates to destination', Gitlab::Tracking::Destinations::SnowplowMicro
    end

    it 'tracks errors' do
      expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception).with(
        an_instance_of(ContractError),
        snowplow_category: nil, snowplow_action: 'some_action'
      )

      described_class.event(nil, 'some_action')
    end
  end

  describe '.definition' do
    let(:namespace) { create(:namespace) }

    let_it_be(:definition_action) { 'definition_action' }
    let_it_be(:definition_category) { 'definition_category' }
    let_it_be(:label_description) { 'definition label description' }
    let_it_be(:test_definition) {{ 'category': definition_category, 'action': definition_action }}

    before do
      allow_next_instance_of(described_class) do |instance|
        allow(instance).to receive(:event)
      end
      allow_next_instance_of(Gitlab::Tracking::Destinations::Snowplow) do |instance|
        allow(instance).to receive(:event)
      end
      allow(YAML).to receive(:load_file).with(Rails.root.join('config/events/filename.yml')).and_return(test_definition)
    end

    it 'dispatchs the data to .event' do
      project = build_stubbed(:project)
      user = build_stubbed(:user)

      expect(described_class).to receive(:event) do |category, action, args|
        expect(category).to eq(definition_category)
        expect(action).to eq(definition_action)
        expect(args[:label]).to eq('label')
        expect(args[:property]).to eq('...')
        expect(args[:project]).to eq(project)
        expect(args[:user]).to eq(user)
        expect(args[:namespace]).to eq(namespace)
        expect(args[:extra_key_1]).to eq('extra value 1')
      end

      described_class.definition('filename', category: nil, action: nil, label: 'label', property: '...',
                                  project: project, user: user, namespace: namespace, extra_key_1: 'extra value 1')
    end
  end
end
