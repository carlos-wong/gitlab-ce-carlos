require 'spec_helper'

describe Gitlab::Ci::Config::Entry::Job do
  let(:entry) { described_class.new(config, name: :rspec) }

  describe '.nodes' do
    context 'when filtering all the entry/node names' do
      subject { described_class.nodes.keys }

      let(:result) do
        %i[before_script script stage type after_script cache
           image services only except variables artifacts
           environment coverage retry]
      end

      it { is_expected.to match_array result }
    end
  end

  describe 'validations' do
    before do
      entry.compose!
    end

    context 'when entry config value is correct' do
      let(:config) { { script: 'rspec' } }

      describe '#valid?' do
        it 'is valid' do
          expect(entry).to be_valid
        end
      end

      context 'when job name is empty' do
        let(:entry) { described_class.new(config, name: ''.to_sym) }

        it 'reports error' do
          expect(entry.errors).to include "job name can't be blank"
        end
      end

      context 'when delayed job' do
        context 'when start_in is specified' do
          let(:config) { { script: 'echo', when: 'delayed', start_in: '1 day' } }

          it { expect(entry).to be_valid }
        end
      end
    end

    context 'when entry value is not correct' do
      context 'incorrect config value type' do
        let(:config) { ['incorrect'] }

        describe '#errors' do
          it 'reports error about a config type' do
            expect(entry.errors)
              .to include 'job config should be a hash'
          end
        end
      end

      context 'when config is empty' do
        let(:config) { {} }

        describe '#valid' do
          it 'is invalid' do
            expect(entry).not_to be_valid
          end
        end
      end

      context 'when unknown keys detected' do
        let(:config) { { unknown: true } }

        describe '#valid' do
          it 'is not valid' do
            expect(entry).not_to be_valid
          end
        end
      end

      context 'when script is not provided' do
        let(:config) { { stage: 'test' } }

        it 'returns error about missing script entry' do
          expect(entry).not_to be_valid
          expect(entry.errors).to include "job script can't be blank"
        end
      end

      context 'when extends key is not a string' do
        let(:config) { { extends: 123 } }

        it 'returns error about wrong value type' do
          expect(entry).not_to be_valid
          expect(entry.errors).to include "job extends should be an array of strings or a string"
        end
      end

      context 'when parallel value is not correct' do
        context 'when it is not a numeric value' do
          let(:config) { { parallel: true } }

          it 'returns error about invalid type' do
            expect(entry).not_to be_valid
            expect(entry.errors).to include 'job parallel is not a number'
          end
        end

        context 'when it is lower than two' do
          let(:config) { { parallel: 1 } }

          it 'returns error about value too low' do
            expect(entry).not_to be_valid
            expect(entry.errors)
              .to include 'job parallel must be greater than or equal to 2'
          end
        end

        context 'when it is bigger than 50' do
          let(:config) { { parallel: 51 } }

          it 'returns error about value too high' do
            expect(entry).not_to be_valid
            expect(entry.errors)
              .to include 'job parallel must be less than or equal to 50'
          end
        end

        context 'when it is not an integer' do
          let(:config) { { parallel: 1.5 } }

          it 'returns error about wrong value' do
            expect(entry).not_to be_valid
            expect(entry.errors).to include 'job parallel must be an integer'
          end
        end
      end

      context 'when delayed job' do
        context 'when start_in is specified' do
          let(:config) { { script: 'echo', when: 'delayed', start_in: '1 day' } }

          it 'returns error about invalid type' do
            expect(entry).to be_valid
          end
        end

        context 'when start_in is empty' do
          let(:config) { { when: 'delayed', start_in: nil } }

          it 'returns error about invalid type' do
            expect(entry).not_to be_valid
            expect(entry.errors).to include 'job start in should be a duration'
          end
        end

        context 'when start_in is not formatted as a duration' do
          let(:config) { { when: 'delayed', start_in: 'test' } }

          it 'returns error about invalid type' do
            expect(entry).not_to be_valid
            expect(entry.errors).to include 'job start in should be a duration'
          end
        end

        context 'when start_in is longer than one day' do
          let(:config) { { when: 'delayed', start_in: '2 days' } }

          it 'returns error about exceeding the limit' do
            expect(entry).not_to be_valid
            expect(entry.errors).to include 'job start in should not exceed the limit'
          end
        end
      end

      context 'when start_in specified without delayed specification' do
        let(:config) { { start_in: '1 day' } }

        it 'returns error about invalid type' do
          expect(entry).not_to be_valid
          expect(entry.errors).to include 'job start in must be blank'
        end
      end
    end
  end

  describe '#relevant?' do
    it 'is a relevant entry' do
      entry = described_class.new({ script: 'rspec' }, name: :rspec)

      expect(entry).to be_relevant
    end
  end

  describe '#compose!' do
    let(:unspecified) { double('unspecified', 'specified?' => false) }

    let(:specified) do
      double('specified', 'specified?' => true, value: 'specified')
    end

    let(:deps) { double('deps', '[]' => unspecified) }

    context 'when job config overrides global config' do
      before do
        entry.compose!(deps)
      end

      let(:config) do
        { script: 'rspec', image: 'some_image', cache: { key: 'test' } }
      end

      it 'overrides global config' do
        expect(entry[:image].value).to eq(name: 'some_image')
        expect(entry[:cache].value).to eq(key: 'test', policy: 'pull-push')
      end
    end

    context 'when job config does not override global config' do
      before do
        allow(deps).to receive('[]').with(:image).and_return(specified)
        entry.compose!(deps)
      end

      let(:config) { { script: 'ls', cache: { key: 'test' } } }

      it 'uses config from global entry' do
        expect(entry[:image].value).to eq 'specified'
        expect(entry[:cache].value).to eq(key: 'test', policy: 'pull-push')
      end
    end
  end

  context 'when composed' do
    before do
      entry.compose!
    end

    describe '#value' do
      before do
        entry.compose!
      end

      context 'when entry is correct' do
        let(:config) do
          { before_script: %w[ls pwd],
            script: 'rspec',
            after_script: %w[cleanup] }
        end

        it 'returns correct value' do
          expect(entry.value)
            .to eq(name: :rspec,
                   before_script: %w[ls pwd],
                   script: %w[rspec],
                   stage: 'test',
                   ignore: false,
                   after_script: %w[cleanup],
                   only: { refs: %w[branches tags] })
        end
      end
    end
  end

  describe '#manual_action?' do
    context 'when job is a manual action' do
      let(:config) { { script: 'deploy', when: 'manual' } }

      it 'is a manual action' do
        expect(entry).to be_manual_action
      end
    end

    context 'when job is not a manual action' do
      let(:config) { { script: 'deploy' } }

      it 'is not a manual action' do
        expect(entry).not_to be_manual_action
      end
    end
  end

  describe '#delayed?' do
    context 'when job is a delayed' do
      let(:config) { { script: 'deploy', when: 'delayed' } }

      it 'is a delayed' do
        expect(entry).to be_delayed
      end
    end

    context 'when job is not a delayed' do
      let(:config) { { script: 'deploy' } }

      it 'is not a delayed' do
        expect(entry).not_to be_delayed
      end
    end
  end

  describe '#ignored?' do
    context 'when job is a manual action' do
      context 'when it is not specified if job is allowed to fail' do
        let(:config) do
          { script: 'deploy', when: 'manual' }
        end

        it 'is an ignored job' do
          expect(entry).to be_ignored
        end
      end

      context 'when job is allowed to fail' do
        let(:config) do
          { script: 'deploy', when: 'manual', allow_failure: true }
        end

        it 'is an ignored job' do
          expect(entry).to be_ignored
        end
      end

      context 'when job is not allowed to fail' do
        let(:config) do
          { script: 'deploy', when: 'manual', allow_failure: false }
        end

        it 'is not an ignored job' do
          expect(entry).not_to be_ignored
        end
      end
    end

    context 'when job is not a manual action' do
      context 'when it is not specified if job is allowed to fail' do
        let(:config) { { script: 'deploy' } }

        it 'is not an ignored job' do
          expect(entry).not_to be_ignored
        end
      end

      context 'when job is allowed to fail' do
        let(:config) { { script: 'deploy', allow_failure: true } }

        it 'is an ignored job' do
          expect(entry).to be_ignored
        end
      end

      context 'when job is not allowed to fail' do
        let(:config) { { script: 'deploy', allow_failure: false } }

        it 'is not an ignored job' do
          expect(entry).not_to be_ignored
        end
      end
    end
  end
end
