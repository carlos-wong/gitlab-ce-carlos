# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Tracking::StandardContext do
  let_it_be(:project) { create(:project) }
  let_it_be(:namespace) { create(:namespace) }
  let_it_be(:user) { create(:user) }

  let(:snowplow_context) { subject.to_context }

  describe '#to_context' do
    context 'environment' do
      shared_examples 'contains environment' do |expected_environment|
        it 'contains environment' do
          expect(snowplow_context.to_json.dig(:data, :environment)).to eq(expected_environment)
        end
      end

      context 'development or test' do
        include_examples 'contains environment', 'development'
      end

      context 'staging' do
        before do
          stub_config_setting(url: Gitlab::Saas.staging_com_url)
        end

        include_examples 'contains environment', 'staging'
      end

      context 'production' do
        before do
          stub_config_setting(url: Gitlab::Saas.com_url)
        end

        include_examples 'contains environment', 'production'
      end

      context 'org' do
        before do
          stub_config_setting(url: Gitlab::Saas.dev_url)
        end

        include_examples 'contains environment', 'org'
      end

      context 'other self-managed instance' do
        before do
          stub_rails_env('production')
        end

        include_examples 'contains environment', 'self-managed'
      end
    end

    it 'contains source' do
      expect(snowplow_context.to_json.dig(:data, :source)).to eq(described_class::GITLAB_RAILS_SOURCE)
    end

    it 'contains context_generated_at timestamp', :freeze_time do
      expect(snowplow_context.to_json.dig(:data, :context_generated_at)).to eq(Time.current)
    end

    context 'plan' do
      context 'when namespace is not available' do
        it 'is nil' do
          expect(snowplow_context.to_json.dig(:data, :plan)).to be_nil
        end
      end

      context 'when namespace is available' do
        subject { described_class.new(namespace: create(:namespace)) }

        it 'contains plan name' do
          expect(snowplow_context.to_json.dig(:data, :plan)).to eq(Plan::DEFAULT)
        end
      end
    end

    context 'with extra data' do
      subject { described_class.new(extra_key_1: 'extra value 1', extra_key_2: 'extra value 2') }

      it 'includes extra data in `extra` hash' do
        expect(snowplow_context.to_json.dig(:data, :extra)).to eq(extra_key_1: 'extra value 1', extra_key_2: 'extra value 2')
      end
    end

    context 'without extra data' do
      it 'contains an empty `extra` hash' do
        expect(snowplow_context.to_json.dig(:data, :extra)).to be_empty
      end
    end

    context 'with incorrect argument type' do
      subject { described_class.new(project: create(:group)) }

      it 'does call `track_and_raise_for_dev_exception`' do
        expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
        snowplow_context
      end
    end

    it 'contains user id' do
      expect(snowplow_context.to_json[:data].keys).to include(:user_id)
    end

    it 'contains namespace and project ids' do
      expect(snowplow_context.to_json[:data].keys).to include(:project_id, :namespace_id)
    end

    it 'accepts just project id as integer' do
      expect { described_class.new(project: 1).to_context }.not_to raise_error
    end
  end
end
