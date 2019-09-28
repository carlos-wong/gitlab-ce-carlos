# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Ci::Build::Step do
  describe '#from_commands' do
    subject { described_class.from_commands(job) }

    before do
      job.run!
    end

    shared_examples 'has correct script' do
      it 'fabricates an object' do
        expect(subject.name).to eq(:script)
        expect(subject.script).to eq(script)
        expect(subject.when).to eq('on_success')
        expect(subject.allow_failure).to be_falsey
      end
    end

    context 'when script option is specified' do
      let(:job) { create(:ci_build, :no_options, options: { script: ["ls -la\necho aaa", "date"] }) }
      let(:script) { ["ls -la\necho aaa", 'date'] }

      it_behaves_like 'has correct script'
    end

    context 'when before and script option is specified' do
      let(:job) do
        create(:ci_build, options: {
          before_script: ["ls -la\necho aaa"],
          script: ["date"]
        })
      end

      let(:script) { ["ls -la\necho aaa", 'date'] }

      it_behaves_like 'has correct script'
    end

    context 'when timeout option is specified in seconds' do
      let(:job) { create(:ci_build, options: { job_timeout: 3, script: ["ls -la\necho aaa", 'date'] }) }
      let(:script) { ["ls -la\necho aaa", 'date'] }

      it_behaves_like 'has correct script'

      it 'has job level timeout' do
        expect(subject.timeout).to eq(3)
      end
    end
  end

  describe '#from_after_script' do
    let(:job) { create(:ci_build) }

    subject { described_class.from_after_script(job) }

    before do
      job.run!
    end

    context 'when after_script is empty' do
      it 'doesn not fabricate an object' do
        is_expected.to be_nil
      end
    end

    context 'when after_script is not empty' do
      let(:job) { create(:ci_build, options: { job_timeout: 60, script: ['bash'], after_script: ['ls -la', 'date'] }) }

      it 'fabricates an object' do
        expect(subject.name).to eq(:after_script)
        expect(subject.script).to eq(['ls -la', 'date'])
        expect(subject.timeout).to eq(60)
        expect(subject.when).to eq('always')
        expect(subject.allow_failure).to be_truthy
      end
    end
  end
end
