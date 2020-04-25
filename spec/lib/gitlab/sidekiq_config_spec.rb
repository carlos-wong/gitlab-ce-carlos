# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::SidekiqConfig do
  describe '.workers' do
    it 'includes all workers' do
      worker_classes = described_class.workers.map(&:klass)

      expect(worker_classes).to include(PostReceive)
      expect(worker_classes).to include(MergeWorker)
    end
  end

  describe '.worker_queues' do
    it 'includes all queues' do
      queues = described_class.worker_queues

      expect(queues).to include('post_receive')
      expect(queues).to include('merge')
      expect(queues).to include('cronjob:stuck_import_jobs')
      expect(queues).to include('mailers')
      expect(queues).to include('default')
    end
  end

  describe '.workers_for_all_queues_yml' do
    it 'returns a tuple with FOSS workers first' do
      expect(described_class.workers_for_all_queues_yml.first)
        .to include(an_object_having_attributes(queue: 'post_receive'))
    end
  end

  describe '.all_queues_yml_outdated?' do
    let(:workers) do
      [
        MergeWorker,
        PostReceive,
        ProcessCommitWorker
      ].map { |worker| described_class::Worker.new(worker, ee: false) }
    end

    before do
      allow(described_class).to receive(:workers).and_return(workers)
      allow(Gitlab).to receive(:ee?).and_return(false)
    end

    it 'returns true if the YAML file does not matcph the application code' do
      allow(YAML).to receive(:load_file)
                       .with(described_class::FOSS_QUEUE_CONFIG_PATH)
                       .and_return(workers.first(2).map(&:to_yaml))

      expect(described_class.all_queues_yml_outdated?).to be(true)
    end

    it 'returns false if the YAML file matches the application code' do
      allow(YAML).to receive(:load_file)
                       .with(described_class::FOSS_QUEUE_CONFIG_PATH)
                       .and_return(workers.map(&:to_yaml))

      expect(described_class.all_queues_yml_outdated?).to be(false)
    end
  end

  describe '.queues_for_sidekiq_queues_yml' do
    before do
      workers = [
        Namespaces::RootStatisticsWorker,
        Namespaces::ScheduleAggregationWorker,
        MergeWorker,
        ProcessCommitWorker
      ].map { |worker| described_class::Worker.new(worker, ee: false) }

      allow(described_class).to receive(:workers).and_return(workers)
    end

    it 'returns queues and weights, aggregating namespaces with the same weight' do
      expected_queues = [
        ['merge', 5],
        ['process_commit', 3],
        ['update_namespace_statistics', 1]
      ]

      expect(described_class.queues_for_sidekiq_queues_yml).to eq(expected_queues)
    end
  end

  describe '.sidekiq_queues_yml_outdated?' do
    before do
      workers = [
        Namespaces::RootStatisticsWorker,
        Namespaces::ScheduleAggregationWorker,
        MergeWorker,
        ProcessCommitWorker
      ].map { |worker| described_class::Worker.new(worker, ee: false) }

      allow(described_class).to receive(:workers).and_return(workers)
    end

    let(:expected_queues) do
      [
        ['merge', 5],
        ['process_commit', 3],
        ['update_namespace_statistics', 1]
      ]
    end

    it 'returns true if the YAML file does not match the application code' do
      allow(YAML).to receive(:load_file)
                       .with(described_class::SIDEKIQ_QUEUES_PATH)
                       .and_return(queues: expected_queues.reverse)

      expect(described_class.sidekiq_queues_yml_outdated?).to be(true)
    end

    it 'returns false if the YAML file matches the application code' do
      allow(YAML).to receive(:load_file)
                       .with(described_class::SIDEKIQ_QUEUES_PATH)
                       .and_return(queues: expected_queues)

      expect(described_class.sidekiq_queues_yml_outdated?).to be(false)
    end
  end
end
