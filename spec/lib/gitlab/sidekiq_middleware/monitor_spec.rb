# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::SidekiqMiddleware::Monitor do
  let(:monitor) { described_class.new }

  describe '#call' do
    let(:worker) { double }
    let(:job) { { 'jid' => 'job-id' } }
    let(:queue) { 'my-queue' }

    it 'calls Gitlab::SidekiqDaemon::Monitor' do
      expect(Gitlab::SidekiqDaemon::Monitor.instance).to receive(:within_job)
        .with('job-id', 'my-queue')
        .and_call_original

      expect { |blk| monitor.call(worker, job, queue, &blk) }.to yield_control
    end

    it 'passthroughs the return value' do
      result = monitor.call(worker, job, queue) do
        'value'
      end

      expect(result).to eq('value')
    end

    context 'when cancel happens' do
      subject do
        monitor.call(worker, job, queue) do
          raise Gitlab::SidekiqDaemon::Monitor::CancelledError
        end
      end

      it 'skips the job' do
        expect { subject }.to raise_error(Sidekiq::JobRetry::Skip)
      end

      it 'puts job in DeadSet' do
        ::Sidekiq::DeadSet.new.clear

        expect do
          subject rescue Sidekiq::JobRetry::Skip
        end.to change { ::Sidekiq::DeadSet.new.size }.by(1)
      end
    end
  end
end
