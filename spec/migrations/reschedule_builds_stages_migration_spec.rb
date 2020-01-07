# frozen_string_literal: true

require 'spec_helper'
require Rails.root.join('db', 'post_migrate', '20180405101928_reschedule_builds_stages_migration')

describe RescheduleBuildsStagesMigration, :sidekiq, :migration do
  let(:namespaces) { table(:namespaces) }
  let(:projects) { table(:projects) }
  let(:pipelines) { table(:ci_pipelines) }
  let(:stages) { table(:ci_stages) }
  let(:jobs) { table(:ci_builds) }

  before do
    stub_const("#{described_class}::BATCH_SIZE", 1)

    namespaces.create(id: 12, name: 'gitlab-org', path: 'gitlab-org')
    projects.create!(id: 123, namespace_id: 12, name: 'gitlab', path: 'gitlab')
    pipelines.create!(id: 1, project_id: 123, ref: 'master', sha: 'adf43c3a')
    stages.create!(id: 1, project_id: 123, pipeline_id: 1, name: 'test')

    jobs.create!(id: 11, commit_id: 1, project_id: 123, stage_id: nil)
    jobs.create!(id: 206, commit_id: 1, project_id: 123, stage_id: nil)
    jobs.create!(id: 3413, commit_id: 1, project_id: 123, stage_id: nil)
    jobs.create!(id: 4109, commit_id: 1, project_id: 123, stage_id: 1)
  end

  it 'schedules delayed background migrations in batches in bulk' do
    Sidekiq::Testing.fake! do
      Timecop.freeze do
        migrate!

        expect(described_class::MIGRATION).to be_scheduled_delayed_migration(5.minutes, 11, 11)
        expect(described_class::MIGRATION).to be_scheduled_delayed_migration(10.minutes, 206, 206)
        expect(described_class::MIGRATION).to be_scheduled_delayed_migration(15.minutes, 3413, 3413)
        expect(BackgroundMigrationWorker.jobs.size).to eq 3
      end
    end
  end
end
