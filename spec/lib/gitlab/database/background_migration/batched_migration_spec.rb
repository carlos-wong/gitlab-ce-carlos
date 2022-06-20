# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Database::BackgroundMigration::BatchedMigration, type: :model do
  it_behaves_like 'having unique enum values'

  it { is_expected.to be_a Gitlab::Database::SharedModel }

  describe 'associations' do
    it { is_expected.to have_many(:batched_jobs).with_foreign_key(:batched_background_migration_id) }

    describe '#last_job' do
      let!(:batched_migration) { create(:batched_background_migration) }
      let!(:batched_job1) { create(:batched_background_migration_job, batched_migration: batched_migration, max_value: 1000) }
      let!(:batched_job2) { create(:batched_background_migration_job, batched_migration: batched_migration, max_value: 500) }

      it 'returns the batched job with highest max_value' do
        expect(batched_migration.last_job).to eq(batched_job1)
      end
    end
  end

  describe 'validations' do
    subject { build(:batched_background_migration) }

    it { is_expected.to validate_uniqueness_of(:job_arguments).scoped_to(:job_class_name, :table_name, :column_name) }

    context 'when there are failed jobs' do
      let(:batched_migration) { create(:batched_background_migration, :active, total_tuple_count: 100) }
      let!(:batched_job) { create(:batched_background_migration_job, :failed, batched_migration: batched_migration) }

      it 'raises an exception' do
        expect { batched_migration.finish! }.to raise_error(StateMachines::InvalidTransition)

        expect(batched_migration.reload.status_name).to be :active
      end
    end

    context 'when the jobs are completed' do
      let(:batched_migration) { create(:batched_background_migration, :active, total_tuple_count: 100) }
      let!(:batched_job) { create(:batched_background_migration_job, :succeeded, batched_migration: batched_migration) }

      it 'finishes the migration' do
        batched_migration.finish!

        expect(batched_migration.status_name).to be :finished
      end
    end
  end

  describe 'state machine' do
    context 'when a migration is executed' do
      let!(:batched_migration) { create(:batched_background_migration) }

      it 'updates the started_at' do
        expect { batched_migration.execute! }.to change(batched_migration, :started_at).from(nil).to(Time)
      end
    end
  end

  describe '.valid_status' do
    valid_status = [:paused, :active, :finished, :failed, :finalizing]

    it 'returns valid status' do
      expect(described_class.valid_status).to eq(valid_status)
    end
  end

  describe '.queue_order' do
    let!(:migration1) { create(:batched_background_migration) }
    let!(:migration2) { create(:batched_background_migration) }
    let!(:migration3) { create(:batched_background_migration) }

    it 'returns batched migrations ordered by their id' do
      expect(described_class.queue_order.all).to eq([migration1, migration2, migration3])
    end
  end

  describe '.active_migration' do
    let!(:migration1) { create(:batched_background_migration, :finished) }

    context 'without migrations on hold' do
      let!(:migration2) { create(:batched_background_migration, :active) }
      let!(:migration3) { create(:batched_background_migration, :active) }

      it 'returns the first active migration according to queue order' do
        expect(described_class.active_migration).to eq(migration2)
      end
    end

    context 'with migrations are on hold' do
      let!(:migration2) { create(:batched_background_migration, :active, on_hold_until: 10.minutes.from_now) }
      let!(:migration3) { create(:batched_background_migration, :active, on_hold_until: 2.minutes.ago) }

      it 'returns the first active migration that is not on hold according to queue order' do
        expect(described_class.active_migration).to eq(migration3)
      end
    end
  end

  describe '.queued' do
    let!(:migration1) { create(:batched_background_migration, :finished) }
    let!(:migration2) { create(:batched_background_migration, :paused) }
    let!(:migration3) { create(:batched_background_migration, :active) }

    it 'returns active and paused migrations' do
      expect(described_class.queued).to contain_exactly(migration2, migration3)
    end
  end

  describe '.successful_rows_counts' do
    let!(:migration1) { create(:batched_background_migration) }
    let!(:migration2) { create(:batched_background_migration) }
    let!(:migration_without_jobs) { create(:batched_background_migration) }

    before do
      create(:batched_background_migration_job, :succeeded, batched_migration: migration1, batch_size: 1000)
      create(:batched_background_migration_job, :failed, batched_migration: migration1, batch_size: 200)
      create(:batched_background_migration_job, :succeeded, batched_migration: migration2, batch_size: 500)
      create(:batched_background_migration_job, :running, batched_migration: migration2, batch_size: 200)
    end

    it 'returns totals from successful jobs' do
      results = described_class.successful_rows_counts([migration1, migration2, migration_without_jobs])

      expect(results[migration1.id]).to eq(1000)
      expect(results[migration2.id]).to eq(500)
      expect(results[migration_without_jobs.id]).to eq(nil)
    end
  end

  describe '#interval_elapsed?' do
    context 'when the migration has no last_job' do
      let(:batched_migration) { build(:batched_background_migration) }

      it 'returns true' do
        expect(batched_migration.interval_elapsed?).to eq(true)
      end
    end

    context 'when the migration has a last_job' do
      let(:interval) { 2.minutes }
      let(:batched_migration) { create(:batched_background_migration, interval: interval) }

      context 'when the last_job is less than an interval old' do
        it 'returns false' do
          freeze_time do
            create(:batched_background_migration_job,
              batched_migration: batched_migration,
              created_at: Time.current - 1.minute)

            expect(batched_migration.interval_elapsed?).to eq(false)
          end
        end
      end

      context 'when the last_job is exactly an interval old' do
        it 'returns true' do
          freeze_time do
            create(:batched_background_migration_job,
              batched_migration: batched_migration,
              created_at: Time.current - 2.minutes)

            expect(batched_migration.interval_elapsed?).to eq(true)
          end
        end
      end

      context 'when the last_job is more than an interval old' do
        it 'returns true' do
          freeze_time do
            create(:batched_background_migration_job,
              batched_migration: batched_migration,
              created_at: Time.current - 3.minutes)

            expect(batched_migration.interval_elapsed?).to eq(true)
          end
        end
      end

      context 'when an interval variance is given' do
        let(:variance) { 2.seconds }

        context 'when the last job is less than an interval with variance old' do
          it 'returns false' do
            freeze_time do
              create(:batched_background_migration_job,
                batched_migration: batched_migration,
                created_at: Time.current - 1.minute - 57.seconds)

              expect(batched_migration.interval_elapsed?(variance: variance)).to eq(false)
            end
          end
        end

        context 'when the last job is more than an interval with variance old' do
          it 'returns true' do
            freeze_time do
              create(:batched_background_migration_job,
                batched_migration: batched_migration,
                created_at: Time.current - 1.minute - 58.seconds)

              expect(batched_migration.interval_elapsed?(variance: variance)).to eq(true)
            end
          end
        end
      end
    end
  end

  describe '#create_batched_job!' do
    let(:batched_migration) do
      create(:batched_background_migration,
             batch_size: 999,
             sub_batch_size: 99,
             pause_ms: 250
            )
    end

    it 'creates a batched_job with the correct batch configuration' do
      batched_job = batched_migration.create_batched_job!(1, 5)

      expect(batched_job).to have_attributes(
        min_value: 1,
        max_value: 5,
        batch_size: batched_migration.batch_size,
        sub_batch_size: batched_migration.sub_batch_size,
        pause_ms: 250
      )
    end
  end

  describe '#next_min_value' do
    let!(:batched_migration) { create(:batched_background_migration) }

    context 'when a previous job exists' do
      let!(:batched_job) { create(:batched_background_migration_job, batched_migration: batched_migration) }

      it 'returns the next value after the previous maximum' do
        expect(batched_migration.next_min_value).to eq(batched_job.max_value + 1)
      end
    end

    context 'when a previous job does not exist' do
      it 'returns the migration minimum value' do
        expect(batched_migration.next_min_value).to eq(batched_migration.min_value)
      end
    end
  end

  describe '#job_class' do
    let(:job_class) { Gitlab::BackgroundMigration::CopyColumnUsingBackgroundMigrationJob }
    let(:batched_migration) { build(:batched_background_migration) }

    it 'returns the class of the job for the migration' do
      expect(batched_migration.job_class).to eq(job_class)
    end
  end

  describe '#batch_class' do
    let(:batch_class) { Gitlab::BackgroundMigration::BatchingStrategies::PrimaryKeyBatchingStrategy}
    let(:batched_migration) { build(:batched_background_migration) }

    it 'returns the class of the batch strategy for the migration' do
      expect(batched_migration.batch_class).to eq(batch_class)
    end
  end

  shared_examples_for 'an attr_writer that assigns class names' do |attribute_name|
    let(:batched_migration) { build(:batched_background_migration) }

    context 'when a module name exists' do
      it 'keeps the class with module name' do
        batched_migration.public_send(:"#{attribute_name}=", 'Foo::Bar')

        expect(batched_migration[attribute_name]).to eq('Foo::Bar')
      end

      it 'removes leading namespace resolution operator' do
        batched_migration.public_send(:"#{attribute_name}=", '::Foo::Bar')

        expect(batched_migration[attribute_name]).to eq('Foo::Bar')
      end
    end

    context 'when a module name does not exist' do
      it 'does not change the given class name' do
        batched_migration.public_send(:"#{attribute_name}=", 'Bar')

        expect(batched_migration[attribute_name]).to eq('Bar')
      end
    end
  end

  describe '#retry_failed_jobs!' do
    let(:batched_migration) { create(:batched_background_migration, status: 'failed') }

    subject(:retry_failed_jobs) { batched_migration.retry_failed_jobs! }

    context 'when there are failed migration jobs' do
      let!(:batched_background_migration_job) { create(:batched_background_migration_job, :failed, batched_migration: batched_migration, batch_size: 10, min_value: 6, max_value: 15, attempts: 3) }

      before do
        allow_next_instance_of(Gitlab::BackgroundMigration::BatchingStrategies::PrimaryKeyBatchingStrategy) do |batch_class|
          allow(batch_class).to receive(:next_batch).with(
            anything,
            anything,
            batch_min_value: 6,
            batch_size: 5,
            job_arguments: batched_migration.job_arguments
          ).and_return([6, 10])
        end
      end

      it 'moves the status of the migration to active' do
        retry_failed_jobs

        expect(batched_migration.status_name).to be :active
      end

      it 'changes the number of attempts to 0' do
        retry_failed_jobs

        expect(batched_background_migration_job.reload.attempts).to be_zero
      end
    end

    context 'when there are no failed migration jobs' do
      it 'moves the status of the migration to active' do
        retry_failed_jobs

        expect(batched_migration.status_name).to be :active
      end
    end
  end

  describe '#should_stop?' do
    subject(:should_stop?) { batched_migration.should_stop? }

    let(:batched_migration) { create(:batched_background_migration, started_at: started_at) }

    before do
      stub_const('Gitlab::Database::BackgroundMigration::BatchedMigration::MINIMUM_JOBS', 1)
    end

    context 'when the started_at is nil' do
      let(:started_at) { nil }

      it { expect(should_stop?).to be_falsey }
    end

    context 'when the number of jobs is lesser than the MINIMUM_JOBS' do
      let(:started_at) { Time.zone.now - 6.days }

      before do
        stub_const('Gitlab::Database::BackgroundMigration::BatchedMigration::MINIMUM_JOBS', 10)
        stub_const('Gitlab::Database::BackgroundMigration::BatchedMigration::MAXIMUM_FAILED_RATIO', 0.70)
        create_list(:batched_background_migration_job, 1, :succeeded, batched_migration: batched_migration)
        create_list(:batched_background_migration_job, 3, :failed, batched_migration: batched_migration)
      end

      it { expect(should_stop?).to be_falsey }
    end

    context 'when the calculated value is greater than the threshold' do
      let(:started_at) { Time.zone.now - 6.days }

      before do
        stub_const('Gitlab::Database::BackgroundMigration::BatchedMigration::MAXIMUM_FAILED_RATIO', 0.70)
        create_list(:batched_background_migration_job, 1, :succeeded, batched_migration: batched_migration)
        create_list(:batched_background_migration_job, 3, :failed, batched_migration: batched_migration)
      end

      it { expect(should_stop?).to be_truthy }
    end

    context 'when the calculated value is lesser than the threshold' do
      let(:started_at) { Time.zone.now - 6.days }

      before do
        create_list(:batched_background_migration_job, 2, :succeeded, batched_migration: batched_migration)
      end

      it { expect(should_stop?).to be_falsey }
    end
  end

  describe '#job_class_name=' do
    it_behaves_like 'an attr_writer that assigns class names', :job_class_name
  end

  describe '#batch_class_name=' do
    it_behaves_like 'an attr_writer that assigns class names', :batch_class_name
  end

  describe '#migrated_tuple_count' do
    subject { batched_migration.migrated_tuple_count }

    let(:batched_migration) { create(:batched_background_migration) }

    before do
      create_list(:batched_background_migration_job, 5, :succeeded, batch_size: 1_000, batched_migration: batched_migration)
      create_list(:batched_background_migration_job, 1, :running, batch_size: 1_000, batched_migration: batched_migration)
      create_list(:batched_background_migration_job, 1, :failed, batch_size: 1_000, batched_migration: batched_migration)
    end

    it 'sums the batch_size of succeeded jobs' do
      expect(subject).to eq(5_000)
    end
  end

  describe '#prometheus_labels' do
    let(:batched_migration) { create(:batched_background_migration, job_class_name: 'TestMigration', table_name: 'foo', column_name: 'bar') }

    it 'returns a hash with labels for the migration' do
      labels = {
        migration_id: batched_migration.id,
        migration_identifier: 'TestMigration/foo.bar'
      }

      expect(batched_migration.prometheus_labels).to eq(labels)
    end
  end

  describe '#smoothed_time_efficiency' do
    let_it_be(:migration) { create(:batched_background_migration, interval: 120.seconds) }
    let_it_be(:end_time) { Time.zone.now }

    around do |example|
      freeze_time do
        example.run
      end
    end

    let_it_be(:common_attrs) do
      {
        batched_migration: migration,
        finished_at: end_time
      }
    end

    context 'when there are not enough jobs' do
      subject { migration.smoothed_time_efficiency(number_of_jobs: 10) }

      it 'returns nil' do
        create_list(:batched_background_migration_job, 9, :succeeded, **common_attrs)

        expect(subject).to be_nil
      end
    end

    context 'when there are enough jobs' do
      let_it_be(:number_of_jobs) { 10 }
      let_it_be(:jobs) { create_list(:batched_background_migration_job, number_of_jobs, **common_attrs.merge(batched_migration: migration)) }

      subject { migration.smoothed_time_efficiency(number_of_jobs: number_of_jobs) }

      let!(:jobs) { create_list(:batched_background_migration_job, number_of_jobs, :succeeded, **common_attrs.merge(batched_migration: migration)) }

      before do
        expect(migration).to receive_message_chain(:batched_jobs, :successful_in_execution_order, :reverse_order, :limit, :with_preloads)
                               .and_return(jobs)
      end

      def mock_efficiencies(*effs)
        effs.each_with_index do |eff, i|
          expect(jobs[i]).to receive(:time_efficiency).and_return(eff)
        end
      end

      context 'example 1: increasing trend, but only recently crossed threshold' do
        it 'returns the smoothed time efficiency' do
          mock_efficiencies(1.1, 1, 0.95, 0.9, 0.8, 0.95, 0.9, 0.8, 0.9, 0.95)

          expect(subject).to be_within(0.05).of(0.95)
        end
      end

      context 'example 2: increasing trend, crossed threshold a while ago' do
        it 'returns the smoothed time efficiency' do
          mock_efficiencies(1.2, 1.1, 1, 1, 1.1, 1, 0.95, 0.9, 0.95, 0.9)

          expect(subject).to be_within(0.05).of(1.1)
        end
      end

      context 'example 3: decreasing trend, but only recently crossed threshold' do
        it 'returns the smoothed time efficiency' do
          mock_efficiencies(0.9, 0.95, 1, 1.2, 1.1, 1.2, 1.1, 1.0, 1.1, 1.0)

          expect(subject).to be_within(0.05).of(1.0)
        end
      end

      context 'example 4: latest run spiked' do
        it 'returns the smoothed time efficiency' do
          mock_efficiencies(1.2, 0.9, 0.8, 0.9, 0.95, 0.9, 0.92, 0.9, 0.95, 0.9)

          expect(subject).to be_within(0.02).of(0.96)
        end
      end
    end

    context 'with preloaded batched migration' do
      it 'avoids N+1' do
        create_list(:batched_background_migration_job, 11, **common_attrs.merge(started_at: end_time - 10.seconds))

        control = ActiveRecord::QueryRecorder.new do
          migration.smoothed_time_efficiency(number_of_jobs: 10)
        end

        expect { migration.smoothed_time_efficiency(number_of_jobs: 11) }.not_to exceed_query_limit(control)
      end
    end
  end

  describe '#optimize!' do
    subject { batched_migration.optimize! }

    let(:batched_migration) { create(:batched_background_migration) }
    let(:optimizer) { instance_double('Gitlab::Database::BackgroundMigration::BatchOptimizer') }

    it 'calls the BatchOptimizer' do
      expect(Gitlab::Database::BackgroundMigration::BatchOptimizer).to receive(:new).with(batched_migration).and_return(optimizer)
      expect(optimizer).to receive(:optimize!)

      subject
    end
  end

  describe '#hold!', :freeze_time do
    subject { create(:batched_background_migration) }

    let(:time) { 5.minutes.from_now }

    it 'updates on_hold_until property' do
      expect { subject.hold!(until_time: time) }.to change { subject.on_hold_until }.from(nil).to(time)
    end

    it 'defaults to 10 minutes' do
      expect { subject.hold! }.to change { subject.on_hold_until }.from(nil).to(10.minutes.from_now)
    end
  end

  describe '.for_configuration' do
    let!(:migration) do
      create(
        :batched_background_migration,
        job_class_name: 'MyJobClass',
        table_name: :projects,
        column_name: :id,
        job_arguments: [[:id], [:id_convert_to_bigint]]
      )
    end

    before do
      create(:batched_background_migration, job_class_name: 'OtherClass')
      create(:batched_background_migration, table_name: 'other_table')
      create(:batched_background_migration, column_name: 'other_column')
      create(:batched_background_migration, job_arguments: %w[other arguments])
    end

    it 'finds the migration matching the given configuration parameters' do
      actual = described_class.for_configuration('MyJobClass', :projects, :id, [[:id], [:id_convert_to_bigint]])

      expect(actual).to contain_exactly(migration)
    end
  end

  describe '.find_for_configuration' do
    it 'returns nill if such migration does not exists' do
      expect(described_class.find_for_configuration('MyJobClass', :projects, :id, [[:id], [:id_convert_to_bigint]])).to be_nil
    end

    it 'returns the migration when it exists' do
      migration = create(
        :batched_background_migration,
        job_class_name: 'MyJobClass',
        table_name: :projects,
        column_name: :id,
        job_arguments: [[:id], [:id_convert_to_bigint]]
      )

      expect(described_class.find_for_configuration('MyJobClass', :projects, :id, [[:id], [:id_convert_to_bigint]])).to eq(migration)
    end
  end
end
