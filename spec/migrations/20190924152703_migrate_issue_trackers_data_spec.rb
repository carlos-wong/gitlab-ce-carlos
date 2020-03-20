# frozen_string_literal: true

require 'spec_helper'
require Rails.root.join('db', 'post_migrate', '20190924152703_migrate_issue_trackers_data.rb')

describe MigrateIssueTrackersData, :migration, :sidekiq do
  let(:services) { table(:services) }
  let(:migration_class) { Gitlab::BackgroundMigration::MigrateIssueTrackersSensitiveData }
  let(:migration_name)  { migration_class.to_s.demodulize }

  let(:properties) do
    {
      'url' => 'http://example.com'
    }
  end
  let!(:jira_service) do
    services.create(id: 10, type: 'JiraService', properties: properties, category: 'issue_tracker')
  end
  let!(:jira_service_nil) do
    services.create(id: 11, type: 'JiraService', properties: nil, category: 'issue_tracker')
  end
  let!(:bugzilla_service) do
    services.create(id: 12, type: 'BugzillaService', properties: properties, category: 'issue_tracker')
  end
  let!(:youtrack_service) do
    services.create(id: 13, type: 'YoutrackService', properties: properties, category: 'issue_tracker')
  end
  let!(:youtrack_service_empty) do
    services.create(id: 14, type: 'YoutrackService', properties: '', category: 'issue_tracker')
  end
  let!(:gitlab_service) do
    services.create(id: 15, type: 'GitlabIssueTrackerService', properties: properties, category: 'issue_tracker')
  end
  let!(:gitlab_service_empty) do
    services.create(id: 16, type: 'GitlabIssueTrackerService', properties: {}, category: 'issue_tracker')
  end
  let!(:other_service) do
    services.create(id: 17, type: 'OtherService', properties: properties, category: 'other_category')
  end

  before do
    stub_const("#{described_class}::BATCH_SIZE", 2)
  end

  it 'schedules background migrations at correct time' do
    Sidekiq::Testing.fake! do
      Timecop.freeze do
        migrate!

        expect(migration_name).to be_scheduled_delayed_migration(3.minutes, jira_service.id, bugzilla_service.id)
        expect(migration_name).to be_scheduled_delayed_migration(6.minutes, youtrack_service.id, gitlab_service.id)
        expect(BackgroundMigrationWorker.jobs.size).to eq(2)
      end
    end
  end
end
