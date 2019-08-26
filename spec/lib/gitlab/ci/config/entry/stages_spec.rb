# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Ci::Config::Entry::Stages do
  let(:entry) { described_class.new(config) }

  describe 'validations' do
    context 'when entry config value is correct' do
      let(:config) { [:stage1, :stage2] }

      describe '#value' do
        it 'returns array of stages' do
          expect(entry.value).to eq config
        end
      end

      describe '#valid?' do
        it 'is valid' do
          expect(entry).to be_valid
        end
      end
    end

    context 'when entry value is not correct' do
      let(:config) { { test: true } }

      describe '#errors' do
        it 'saves errors' do
          expect(entry.errors)
            .to include 'stages config should be an array of strings'
        end
      end

      describe '#valid?' do
        it 'is not valid' do
          expect(entry).not_to be_valid
        end
      end
    end
  end

  describe '.default' do
    it 'returns default stages' do
      expect(described_class.default).to eq %w[build test deploy]
    end
  end
end
