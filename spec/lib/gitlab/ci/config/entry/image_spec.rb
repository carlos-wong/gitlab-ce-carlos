# frozen_string_literal: true

require 'fast_spec_helper'
require 'support/helpers/stubbed_feature'
require 'support/helpers/stub_feature_flags'

RSpec.describe Gitlab::Ci::Config::Entry::Image do
  include StubFeatureFlags

  before do
    stub_feature_flags(ci_docker_image_pull_policy: true)

    entry.compose!
  end

  let(:entry) { described_class.new(config) }

  context 'when configuration is a string' do
    let(:config) { 'image:1.0' }

    describe '#value' do
      it 'returns image hash' do
        expect(entry.value).to eq({ name: 'image:1.0' })
      end
    end

    describe '#errors' do
      it 'does not append errors' do
        expect(entry.errors).to be_empty
      end
    end

    describe '#valid?' do
      it 'is valid' do
        expect(entry).to be_valid
      end
    end

    describe '#image' do
      it "returns image's name" do
        expect(entry.name).to eq 'image:1.0'
      end
    end

    describe '#entrypoint' do
      it "returns image's entrypoint" do
        expect(entry.entrypoint).to be_nil
      end
    end

    describe '#ports' do
      it "returns image's ports" do
        expect(entry.ports).to be_nil
      end
    end

    describe '#pull_policy' do
      it "returns nil" do
        expect(entry.pull_policy).to be_nil
      end
    end
  end

  context 'when configuration is a hash' do
    let(:config) { { name: 'image:1.0', entrypoint: %w(/bin/sh run) } }

    describe '#value' do
      it 'returns image hash' do
        expect(entry.value).to eq(config)
      end
    end

    describe '#errors' do
      it 'does not append errors' do
        expect(entry.errors).to be_empty
      end
    end

    describe '#valid?' do
      it 'is valid' do
        expect(entry).to be_valid
      end
    end

    describe '#image' do
      it "returns image's name" do
        expect(entry.name).to eq 'image:1.0'
      end
    end

    describe '#entrypoint' do
      it "returns image's entrypoint" do
        expect(entry.entrypoint).to eq %w(/bin/sh run)
      end
    end

    context 'when configuration has ports' do
      let(:ports) { [{ number: 80, protocol: 'http', name: 'foobar' }] }
      let(:config) { { name: 'image:1.0', entrypoint: %w(/bin/sh run), ports: ports } }
      let(:entry) { described_class.new(config, with_image_ports: image_ports) }
      let(:image_ports) { false }

      context 'when with_image_ports metadata is not enabled' do
        describe '#valid?' do
          it 'is not valid' do
            expect(entry).not_to be_valid
            expect(entry.errors).to include("image config contains disallowed keys: ports")
          end
        end
      end

      context 'when with_image_ports metadata is enabled' do
        let(:image_ports) { true }

        describe '#valid?' do
          it 'is valid' do
            expect(entry).to be_valid
          end
        end

        describe '#ports' do
          it "returns image's ports" do
            expect(entry.ports).to eq ports
          end
        end
      end
    end

    context 'when configuration has pull_policy' do
      let(:config) { { name: 'image:1.0', pull_policy: 'if-not-present' } }

      describe '#valid?' do
        it 'is valid' do
          expect(entry).to be_valid
        end

        context 'when the feature flag ci_docker_image_pull_policy is disabled' do
          before do
            stub_feature_flags(ci_docker_image_pull_policy: false)
            entry.compose!
          end

          it 'is not valid' do
            expect(entry).not_to be_valid
            expect(entry.errors).to include('image config contains unknown keys: pull_policy')
          end
        end
      end

      describe '#value' do
        it "returns value" do
          expect(entry.value).to eq(
            name: 'image:1.0',
            pull_policy: ['if-not-present']
          )
        end

        context 'when the feature flag ci_docker_image_pull_policy is disabled' do
          before do
            stub_feature_flags(ci_docker_image_pull_policy: false)
            entry.compose!
          end

          it 'is not valid' do
            expect(entry.value).to eq(
              name: 'image:1.0'
            )
          end
        end
      end
    end
  end

  context 'when entry value is not correct' do
    let(:config) { ['image:1.0'] }

    describe '#errors' do
      it 'saves errors' do
        expect(entry.errors.first)
          .to match /config should be a hash or a string/
      end
    end

    describe '#valid?' do
      it 'is not valid' do
        expect(entry).not_to be_valid
      end
    end
  end

  context 'when unexpected key is specified' do
    let(:config) { { name: 'image:1.0', non_existing: 'test' } }

    describe '#errors' do
      it 'saves errors' do
        expect(entry.errors.first)
          .to match /config contains unknown keys: non_existing/
      end
    end

    describe '#valid?' do
      it 'is not valid' do
        expect(entry).not_to be_valid
      end
    end
  end
end
