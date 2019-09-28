require 'spec_helper'

describe Gitlab::Ci::Build::Rules do
  let(:pipeline) { create(:ci_pipeline) }
  let(:ci_build) { build(:ci_build, pipeline: pipeline) }

  let(:seed) do
    double('build seed',
      to_resource: ci_build,
      scoped_variables_hash: ci_build.scoped_variables_hash
    )
  end

  let(:rules) { described_class.new(rule_list) }

  describe '.new' do
    let(:rules_ivar)   { rules.instance_variable_get :@rule_list }
    let(:default_when) { rules.instance_variable_get :@default_when }

    context 'with no rules' do
      let(:rule_list) { [] }

      it 'sets @rule_list to an empty array' do
        expect(rules_ivar).to eq([])
      end

      it 'sets @default_when to "on_success"' do
        expect(default_when).to eq('on_success')
      end
    end

    context 'with one rule' do
      let(:rule_list) { [{ if: '$VAR == null', when: 'always' }] }

      it 'sets @rule_list to an array of a single rule' do
        expect(rules_ivar).to be_an(Array)
      end

      it 'sets @default_when to "on_success"' do
        expect(default_when).to eq('on_success')
      end
    end

    context 'with multiple rules' do
      let(:rule_list) do
        [
          { if: '$VAR == null', when: 'always' },
          { if: '$VAR == null', when: 'always' }
        ]
      end

      it 'sets @rule_list to an array of a single rule' do
        expect(rules_ivar).to be_an(Array)
      end

      it 'sets @default_when to "on_success"' do
        expect(default_when).to eq('on_success')
      end
    end

    context 'with a specified default when:' do
      let(:rule_list) { [{ if: '$VAR == null', when: 'always' }] }
      let(:rules)     { described_class.new(rule_list, 'manual') }

      it 'sets @rule_list to an array of a single rule' do
        expect(rules_ivar).to be_an(Array)
      end

      it 'sets @default_when to "manual"' do
        expect(default_when).to eq('manual')
      end
    end
  end

  describe '#evaluate' do
    subject { rules.evaluate(pipeline, seed) }

    context 'with nil rules' do
      let(:rule_list) { nil }

      it { is_expected.to eq(described_class::Result.new('on_success')) }

      context 'and when:manual set as the default' do
        let(:rules) { described_class.new(rule_list, 'manual') }

        it { is_expected.to eq(described_class::Result.new('manual')) }
      end
    end

    context 'with no rules' do
      let(:rule_list) { [] }

      it { is_expected.to eq(described_class::Result.new('never')) }

      context 'and when:manual set as the default' do
        let(:rules) { described_class.new(rule_list, 'manual') }

        it { is_expected.to eq(described_class::Result.new('never')) }
      end
    end

    context 'with one rule without any clauses' do
      let(:rule_list) { [{ when: 'manual' }] }

      it { is_expected.to eq(described_class::Result.new('manual')) }
    end

    context 'with one matching rule' do
      let(:rule_list) { [{ if: '$VAR == null', when: 'always' }] }

      it { is_expected.to eq(described_class::Result.new('always')) }
    end

    context 'with two matching rules' do
      let(:rule_list) do
        [
          { if: '$VAR == null', when: 'delayed', start_in: '1 day' },
          { if: '$VAR == null', when: 'always' }
        ]
      end

      it 'returns the value of the first matched rule in the list' do
        expect(subject).to eq(described_class::Result.new('delayed', '1 day'))
      end
    end

    context 'with a non-matching and matching rule' do
      let(:rule_list) do
        [
          { if: '$VAR =! null', when: 'delayed', start_in: '1 day' },
          { if: '$VAR == null', when: 'always' }
        ]
      end

      it { is_expected.to eq(described_class::Result.new('always')) }
    end

    context 'with a matching and non-matching rule' do
      let(:rule_list) do
        [
          { if: '$VAR == null', when: 'delayed', start_in: '1 day' },
          { if: '$VAR != null', when: 'always' }
        ]
      end

      it { is_expected.to eq(described_class::Result.new('delayed', '1 day')) }
    end

    context 'with non-matching rules' do
      let(:rule_list) do
        [
          { if: '$VAR != null', when: 'delayed', start_in: '1 day' },
          { if: '$VAR != null', when: 'always' }
        ]
      end

      it { is_expected.to eq(described_class::Result.new('never')) }

      context 'and when:manual set as the default' do
        let(:rules) { described_class.new(rule_list, 'manual') }

        it 'does not return the default when:' do
          expect(subject).to eq(described_class::Result.new('never'))
        end
      end
    end
  end
end
