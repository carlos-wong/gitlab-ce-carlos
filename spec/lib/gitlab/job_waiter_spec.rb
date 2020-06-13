# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::JobWaiter do
  describe '.notify' do
    it 'pushes the jid to the named queue' do
      key = 'gitlab:job_waiter:foo'
      jid = 1

      redis = double('redis')
      expect(Gitlab::Redis::SharedState).to receive(:with).and_yield(redis)
      expect(redis).to receive(:lpush).with(key, jid)

      described_class.notify(key, jid)
    end
  end

  describe '#wait' do
    let(:waiter) { described_class.new(2) }

    it 'returns when all jobs have been completed' do
      described_class.notify(waiter.key, 'a')
      described_class.notify(waiter.key, 'b')

      result = nil
      expect { Timeout.timeout(1) { result = waiter.wait(2) } }.not_to raise_error

      expect(result).to contain_exactly('a', 'b')
    end

    it 'times out if not all jobs complete' do
      described_class.notify(waiter.key, 'a')

      result = nil
      expect { Timeout.timeout(2) { result = waiter.wait(1) } }.not_to raise_error

      expect(result).to contain_exactly('a')
    end

    context 'when a label is provided' do
      let(:waiter) { described_class.new(2, worker_label: 'Foo') }
      let(:started_total) { double(:started_total) }
      let(:timeouts_total) { double(:timeouts_total) }

      before do
        allow(Gitlab::Metrics).to receive(:counter)
                                    .with(described_class::STARTED_METRIC, anything)
                                    .and_return(started_total)

        allow(Gitlab::Metrics).to receive(:counter)
                                    .with(described_class::TIMEOUTS_METRIC, anything)
                                    .and_return(timeouts_total)
      end

      it 'increments just job_waiter_started_total when all jobs complete' do
        expect(started_total).to receive(:increment).with(worker: 'Foo')
        expect(timeouts_total).not_to receive(:increment)

        described_class.notify(waiter.key, 'a')
        described_class.notify(waiter.key, 'b')

        result = nil
        expect { Timeout.timeout(1) { result = waiter.wait(2) } }.not_to raise_error
      end

      it 'increments job_waiter_started_total and job_waiter_timeouts_total when it times out' do
        expect(started_total).to receive(:increment).with(worker: 'Foo')
        expect(timeouts_total).to receive(:increment).with(worker: 'Foo')

        result = nil
        expect { Timeout.timeout(2) { result = waiter.wait(1) } }.not_to raise_error
      end
    end
  end
end
