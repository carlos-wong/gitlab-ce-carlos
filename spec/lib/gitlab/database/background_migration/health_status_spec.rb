# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Database::BackgroundMigration::HealthStatus do
  let(:connection) { Gitlab::Database.database_base_models[:main].connection }

  around do |example|
    Gitlab::Database::SharedModel.using_connection(connection) do
      example.run
    end
  end

  describe '.evaluate' do
    subject(:evaluate) { described_class.evaluate(migration, indicator_class) }

    let(:migration) { build(:batched_background_migration, :active) }

    let(:health_status) { 'Gitlab::Database::BackgroundMigration::HealthStatus' }
    let(:indicator_class) { class_double("#{health_status}::Indicators::AutovacuumActiveOnTable") }
    let(:indicator) { instance_double("#{health_status}::Indicators::AutovacuumActiveOnTable") }

    before do
      allow(indicator_class).to receive(:new).with(migration.health_context).and_return(indicator)
    end

    it 'returns a signal' do
      signal = instance_double("#{health_status}::Signals::Normal", log_info?: false)

      expect(indicator).to receive(:evaluate).and_return(signal)

      expect(evaluate).to eq(signal)
    end

    it 'logs interesting signals' do
      signal = instance_double("#{health_status}::Signals::Stop", log_info?: true)

      expect(indicator).to receive(:evaluate).and_return(signal)
      expect(described_class).to receive(:log_signal).with(signal, migration)

      evaluate
    end

    it 'does not log signals of no interest' do
      signal = instance_double("#{health_status}::Signals::Normal", log_info?: false)

      expect(indicator).to receive(:evaluate).and_return(signal)
      expect(described_class).not_to receive(:log_signal)

      evaluate
    end

    context 'on indicator error' do
      let(:error) { RuntimeError.new('everything broken') }

      before do
        expect(indicator).to receive(:evaluate).and_raise(error)
      end

      it 'does not fail' do
        expect { evaluate }.not_to raise_error
      end

      it 'returns Unknown signal' do
        expect(evaluate).to be_an_instance_of(Gitlab::Database::BackgroundMigration::HealthStatus::Signals::Unknown)
        expect(evaluate.reason).to eq("unexpected error: everything broken (RuntimeError)")
      end

      it 'reports the exception to error tracking' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception)
          .with(error, migration_id: migration.id, job_class_name: migration.job_class_name)

        evaluate
      end
    end
  end
end
