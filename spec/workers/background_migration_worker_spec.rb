# frozen_string_literal: true

require 'spec_helper'

describe BackgroundMigrationWorker, :clean_gitlab_redis_shared_state do
  let(:worker) { described_class.new }

  describe '.minimum_interval' do
    it 'returns 2 minutes' do
      expect(described_class.minimum_interval).to eq(2.minutes.to_i)
    end
  end

  describe '#perform' do
    it 'performs a background migration' do
      expect(Gitlab::BackgroundMigration)
        .to receive(:perform)
        .with('Foo', [10, 20])

      worker.perform('Foo', [10, 20])
    end

    it 'reschedules a migration if it was performed recently' do
      expect(worker)
        .to receive(:always_perform?)
        .and_return(false)

      worker.lease_for('Foo').try_obtain

      expect(Gitlab::BackgroundMigration)
        .not_to receive(:perform)

      expect(described_class)
        .to receive(:perform_in)
        .with(a_kind_of(Numeric), 'Foo', [10, 20])

      worker.perform('Foo', [10, 20])
    end

    it 'reschedules a migration if the database is not healthy' do
      allow(worker)
        .to receive(:always_perform?)
        .and_return(false)

      allow(worker)
        .to receive(:healthy_database?)
        .and_return(false)

      expect(described_class)
        .to receive(:perform_in)
        .with(a_kind_of(Numeric), 'Foo', [10, 20])

      worker.perform('Foo', [10, 20])
    end

    it 'sets the class that will be executed as the caller_id' do
      expect(Gitlab::BackgroundMigration).to receive(:perform) do
        expect(Labkit::Context.current.to_h).to include('meta.caller_id' => 'Foo')
      end

      worker.perform('Foo', [10, 20])
    end
  end

  describe '#healthy_database?' do
    context 'when replication lag is too great' do
      it 'returns false' do
        allow(Postgresql::ReplicationSlot)
          .to receive(:lag_too_great?)
          .and_return(true)

        expect(worker.healthy_database?).to eq(false)
      end

      context 'when replication lag is small enough' do
        it 'returns true' do
          allow(Postgresql::ReplicationSlot)
            .to receive(:lag_too_great?)
            .and_return(false)

          expect(worker.healthy_database?).to eq(true)
        end
      end
    end
  end
end
