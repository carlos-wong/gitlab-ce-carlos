require 'spec_helper'

describe Gitlab::RepositoryCache do
  let(:backend) { double('backend').as_null_object }
  let(:project) { create(:project) }
  let(:repository) { project.repository }
  let(:namespace) { "#{repository.full_path}:#{project.id}" }
  let(:cache) { described_class.new(repository, backend: backend) }

  describe '#cache_key' do
    subject { cache.cache_key(:foo) }

    it 'includes the namespace' do
      expect(subject).to eq "foo:#{namespace}"
    end

    context 'with a given namespace' do
      let(:extra_namespace) { 'my:data' }
      let(:cache) do
        described_class.new(repository, extra_namespace: extra_namespace,
                                        backend: backend)
      end

      it 'includes the full namespace' do
        expect(subject).to eq "foo:#{namespace}:#{extra_namespace}"
      end
    end
  end

  describe '#expire' do
    it 'expires the given key from the cache' do
      cache.expire(:foo)
      expect(backend).to have_received(:delete).with("foo:#{namespace}")
    end
  end

  describe '#fetch' do
    it 'fetches the given key from the cache' do
      cache.fetch(:bar)
      expect(backend).to have_received(:fetch).with("bar:#{namespace}")
    end

    it 'accepts a block' do
      p = -> {}

      cache.fetch(:baz, &p)
      expect(backend).to have_received(:fetch).with("baz:#{namespace}", &p)
    end
  end

  describe '#fetch_without_caching_false', :use_clean_rails_memory_store_caching do
    let(:key) { :foo }
    let(:backend) { Rails.cache }

    it 'requires a block' do
      expect do
        cache.fetch_without_caching_false(key)
      end.to raise_error(LocalJumpError)
    end

    context 'when the key does not exist in the cache' do
      context 'when the result of the block is truthy' do
        it 'returns the result of the block' do
          result = cache.fetch_without_caching_false(key) { true }

          expect(result).to be true
        end

        it 'caches the value' do
          expect(backend).to receive(:write).with("#{key}:#{namespace}", true)

          cache.fetch_without_caching_false(key) { true }
        end
      end

      context 'when the result of the block is falsey' do
        let(:p) { -> { false } }

        it 'returns the result of the block' do
          result = cache.fetch_without_caching_false(key, &p)

          expect(result).to be false
        end

        it 'does not cache the value' do
          expect(backend).not_to receive(:write).with("#{key}:#{namespace}", true)

          cache.fetch_without_caching_false(key, &p)
        end
      end
    end

    context 'when the cached value is truthy' do
      before do
        backend.write("#{key}:#{namespace}", true)
      end

      it 'returns the cached value' do
        result = cache.fetch_without_caching_false(key) { 'block result' }

        expect(result).to be true
      end

      it 'does not execute the block' do
        expect do |b|
          cache.fetch_without_caching_false(key, &b)
        end.not_to yield_control
      end

      it 'does not write to the cache' do
        expect(backend).not_to receive(:write)

        cache.fetch_without_caching_false(key) { 'block result' }
      end
    end

    context 'when the cached value is falsey' do
      before do
        backend.write("#{key}:#{namespace}", false)
      end

      it 'returns the result of the block' do
        result = cache.fetch_without_caching_false(key) { 'block result' }

        expect(result).to eq 'block result'
      end

      it 'writes the truthy value to the cache' do
        expect(backend).to receive(:write).with("#{key}:#{namespace}", 'block result')

        cache.fetch_without_caching_false(key) { 'block result' }
      end
    end
  end
end
