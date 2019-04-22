# frozen_string_literal: true

require 'spec_helper'

describe Ci::BuildTraceChunks::Redis, :clean_gitlab_redis_shared_state do
  let(:data_store) { described_class.new }

  describe '#available?' do
    subject { data_store.available? }

    it { is_expected.to be_truthy }
  end

  describe '#data' do
    subject { data_store.data(model) }

    context 'when data exists' do
      let(:model) { create(:ci_build_trace_chunk, :redis_with_data, initial_data: 'sample data in redis') }

      it 'returns the data' do
        is_expected.to eq('sample data in redis')
      end
    end

    context 'when data does not exist' do
      let(:model) { create(:ci_build_trace_chunk, :redis_without_data) }

      it 'returns nil' do
        is_expected.to be_nil
      end
    end
  end

  describe '#set_data' do
    subject { data_store.set_data(model, data) }

    let(:data) { 'abc123' }

    context 'when data exists' do
      let(:model) { create(:ci_build_trace_chunk, :redis_with_data, initial_data: 'sample data in redis') }

      it 'overwrites data' do
        expect(data_store.data(model)).to eq('sample data in redis')

        subject

        expect(data_store.data(model)).to eq('abc123')
      end
    end

    context 'when data does not exist' do
      let(:model) { create(:ci_build_trace_chunk, :redis_without_data) }

      it 'sets new data' do
        expect(data_store.data(model)).to be_nil

        subject

        expect(data_store.data(model)).to eq('abc123')
      end
    end
  end

  describe '#delete_data' do
    subject { data_store.delete_data(model) }

    context 'when data exists' do
      let(:model) { create(:ci_build_trace_chunk, :redis_with_data, initial_data: 'sample data in redis') }

      it 'deletes data' do
        expect(data_store.data(model)).to eq('sample data in redis')

        subject

        expect(data_store.data(model)).to be_nil
      end
    end

    context 'when data does not exist' do
      let(:model) { create(:ci_build_trace_chunk, :redis_without_data) }

      it 'does nothing' do
        expect(data_store.data(model)).to be_nil

        subject

        expect(data_store.data(model)).to be_nil
      end
    end
  end

  describe '#keys' do
    subject { data_store.keys(relation) }

    let(:build) { create(:ci_build) }
    let(:relation) { build.trace_chunks }

    before do
      create(:ci_build_trace_chunk, :redis_with_data, chunk_index: 0, build: build)
      create(:ci_build_trace_chunk, :redis_with_data, chunk_index: 1, build: build)
    end

    it 'returns keys' do
      is_expected.to eq([[build.id, 0], [build.id, 1]])
    end
  end

  describe '#delete_keys' do
    subject { data_store.delete_keys(keys) }

    let(:build) { create(:ci_build) }
    let(:relation) { build.trace_chunks }
    let(:keys) { data_store.keys(relation) }

    before do
      create(:ci_build_trace_chunk, :redis_with_data, chunk_index: 0, build: build)
      create(:ci_build_trace_chunk, :redis_with_data, chunk_index: 1, build: build)
    end

    it 'deletes multiple data' do
      Gitlab::Redis::SharedState.with do |redis|
        expect(redis.exists("gitlab:ci:trace:#{build.id}:chunks:0")).to be_truthy
        expect(redis.exists("gitlab:ci:trace:#{build.id}:chunks:1")).to be_truthy
      end

      subject

      Gitlab::Redis::SharedState.with do |redis|
        expect(redis.exists("gitlab:ci:trace:#{build.id}:chunks:0")).to be_falsy
        expect(redis.exists("gitlab:ci:trace:#{build.id}:chunks:1")).to be_falsy
      end
    end
  end
end
