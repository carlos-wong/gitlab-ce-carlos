# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::SafeRequestStore do
  describe '.store' do
    context 'when RequestStore is active', :request_store do
      it 'uses RequestStore' do
        expect(described_class.store).to eq(RequestStore)
      end
    end

    context 'when RequestStore is NOT active' do
      it 'does not use RequestStore' do
        expect(described_class.store).to be_a(Gitlab::NullRequestStore)
      end
    end
  end

  describe '.begin!' do
    context 'when RequestStore is active', :request_store do
      it 'uses RequestStore' do
        expect(RequestStore).to receive(:begin!)

        described_class.begin!
      end
    end

    context 'when RequestStore is NOT active' do
      it 'uses RequestStore' do
        expect(RequestStore).to receive(:begin!)

        described_class.begin!
      end
    end
  end

  describe '.clear!' do
    context 'when RequestStore is active', :request_store do
      it 'uses RequestStore' do
        expect(RequestStore).to receive(:clear!).once.and_call_original

        described_class.clear!
      end
    end

    context 'when RequestStore is NOT active' do
      it 'uses RequestStore' do
        expect(RequestStore).to receive(:clear!).and_call_original

        described_class.clear!
      end
    end
  end

  describe '.end!' do
    context 'when RequestStore is active', :request_store do
      it 'uses RequestStore' do
        expect(RequestStore).to receive(:end!).once.and_call_original

        described_class.end!
      end
    end

    context 'when RequestStore is NOT active' do
      it 'uses RequestStore' do
        expect(RequestStore).to receive(:end!).and_call_original

        described_class.end!
      end
    end
  end

  describe '.write' do
    context 'when RequestStore is active', :request_store do
      it 'uses RequestStore' do
        expect do
          described_class.write('foo', true)
        end.to change { described_class.read('foo') }.from(nil).to(true)
      end

      it 'does not pass the options hash to the underlying store implementation' do
        expect(described_class.store).to receive(:write).with('foo', true)

        described_class.write('foo', true, expires_in: 15.seconds)
      end
    end

    context 'when RequestStore is NOT active' do
      it 'does not use RequestStore' do
        expect do
          described_class.write('foo', true)
        end.not_to change { described_class.read('foo') }.from(nil)
      end

      it 'does not pass the options hash to the underlying store implementation' do
        expect(described_class.store).to receive(:write).with('foo', true)

        described_class.write('foo', true, expires_in: 15.seconds)
      end
    end
  end

  describe '.[]=' do
    context 'when RequestStore is active', :request_store do
      it 'uses RequestStore' do
        expect do
          described_class['foo'] = true
        end.to change { described_class.read('foo') }.from(nil).to(true)
      end
    end

    context 'when RequestStore is NOT active' do
      it 'does not use RequestStore' do
        expect do
          described_class['foo'] = true
        end.not_to change { described_class.read('foo') }.from(nil)
      end
    end
  end

  describe '.read' do
    context 'when RequestStore is active', :request_store do
      it 'uses RequestStore' do
        expect do
          RequestStore.write('foo', true)
        end.to change { described_class.read('foo') }.from(nil).to(true)
      end
    end

    context 'when RequestStore is NOT active' do
      it 'does not use RequestStore' do
        expect do
          RequestStore.write('foo', true)
        end.not_to change { described_class.read('foo') }.from(nil)

        RequestStore.clear! # Clean up
      end
    end
  end

  describe '.[]' do
    context 'when RequestStore is active', :request_store do
      it 'uses RequestStore' do
        expect do
          RequestStore.write('foo', true)
        end.to change { described_class['foo'] }.from(nil).to(true)
      end
    end

    context 'when RequestStore is NOT active' do
      it 'does not use RequestStore' do
        expect do
          RequestStore.write('foo', true)
        end.not_to change { described_class['foo'] }.from(nil)

        RequestStore.clear! # Clean up
      end
    end
  end

  describe '.exist?' do
    context 'when RequestStore is active', :request_store do
      it 'uses RequestStore' do
        expect do
          RequestStore.write('foo', 'not nil')
        end.to change { described_class.exist?('foo') }.from(false).to(true)
      end
    end

    context 'when RequestStore is NOT active' do
      it 'does not use RequestStore' do
        expect do
          RequestStore.write('foo', 'not nil')
        end.not_to change { described_class.exist?('foo') }.from(false)

        RequestStore.clear! # Clean up
      end
    end
  end

  describe '.fetch' do
    context 'when RequestStore is active', :request_store do
      it 'uses RequestStore' do
        expect do
          described_class.fetch('foo') { 'block result' }
        end.to change { described_class.read('foo') }.from(nil).to('block result')
      end
    end

    context 'when RequestStore is NOT active' do
      it 'does not use RequestStore' do
        RequestStore.clear! # Ensure clean

        expect do
          described_class.fetch('foo') { 'block result' }
        end.not_to change { described_class.read('foo') }.from(nil)

        RequestStore.clear! # Clean up
      end
    end
  end

  describe '.delete' do
    context 'when RequestStore is active', :request_store do
      it 'uses RequestStore' do
        described_class.write('foo', true)

        expect do
          described_class.delete('foo')
        end.to change { described_class.read('foo') }.from(true).to(nil)
      end

      context 'when given a block and the key exists' do
        it 'does not execute the block' do
          described_class.write('foo', true)

          expect do |b|
            described_class.delete('foo', &b)
          end.not_to yield_control
        end
      end

      context 'when given a block and the key does not exist' do
        it 'yields the key and returns the block result' do
          result = described_class.delete('foo') { |key| "#{key} block result" }

          expect(result).to eq('foo block result')
        end
      end
    end

    context 'when RequestStore is NOT active' do
      before do
        RequestStore.write('foo', true)
      end

      after do
        RequestStore.clear! # Clean up
      end

      it 'does not use RequestStore' do
        expect do
          described_class.delete('foo')
        end.not_to change { RequestStore.read('foo') }.from(true)
      end

      context 'when given a block' do
        it 'yields the key and returns the block result' do
          result = described_class.delete('foo') { |key| "#{key} block result" }

          expect(result).to eq('foo block result')
        end
      end
    end
  end
end
