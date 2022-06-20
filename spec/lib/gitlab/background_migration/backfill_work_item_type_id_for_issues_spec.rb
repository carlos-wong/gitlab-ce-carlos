# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillWorkItemTypeIdForIssues, :migration, schema: 20220326161803 do
  subject(:migrate) { migration.perform(start_id, end_id, batch_table, batch_column, sub_batch_size, pause_ms, issue_type_enum[:issue], issue_type.id) }

  let(:migration) { described_class.new }

  let(:batch_table) { 'issues' }
  let(:batch_column) { 'id' }
  let(:sub_batch_size) { 2 }
  let(:pause_ms) { 0 }

  # let_it_be can't be used in migration specs because all tables but `work_item_types` are deleted after each spec
  let(:issue_type_enum) { { issue: 0, incident: 1, test_case: 2, requirement: 3, task: 4 } }
  let(:namespace) { table(:namespaces).create!(name: 'namespace', path: 'namespace') }
  let(:project) { table(:projects).create!(namespace_id: namespace.id) }
  let(:issues_table) { table(:issues) }
  let(:issue_type) { table(:work_item_types).find_by!(namespace_id: nil, base_type: issue_type_enum[:issue]) }

  let(:issue1) { issues_table.create!(project_id: project.id, issue_type: issue_type_enum[:issue]) }
  let(:issue2) { issues_table.create!(project_id: project.id, issue_type: issue_type_enum[:issue]) }
  let(:issue3) { issues_table.create!(project_id: project.id, issue_type: issue_type_enum[:issue]) }
  let(:incident1) { issues_table.create!(project_id: project.id, issue_type: issue_type_enum[:incident]) }
  # test_case and requirement are EE only, but enum values exist on the FOSS model
  let(:test_case1) { issues_table.create!(project_id: project.id, issue_type: issue_type_enum[:test_case]) }
  let(:requirement1) { issues_table.create!(project_id: project.id, issue_type: issue_type_enum[:requirement]) }

  let(:start_id) { issue1.id }
  let(:end_id) { requirement1.id }

  let(:all_issues) { [issue1, issue2, issue3, incident1, test_case1, requirement1] }

  it 'sets work_item_type_id only for the given type' do
    expect(all_issues).to all(have_attributes(work_item_type_id: nil))

    expect { migrate }.to make_queries_matching(/UPDATE \"issues\" SET "work_item_type_id"/, 2)
    all_issues.each(&:reload)

    expect([issue1, issue2, issue3]).to all(have_attributes(work_item_type_id: issue_type.id))
    expect(all_issues - [issue1, issue2, issue3]).to all(have_attributes(work_item_type_id: nil))
  end

  it 'tracks timings of queries' do
    expect(migration.batch_metrics.timings).to be_empty

    expect { migrate }.to change { migration.batch_metrics.timings }
  end

  context 'when database timeouts' do
    using RSpec::Parameterized::TableSyntax

    where(error_class: [ActiveRecord::StatementTimeout, ActiveRecord::QueryCanceled])

    with_them do
      it 'retries on timeout error' do
        expect(migration).to receive(:update_batch).exactly(3).times.and_raise(error_class)
        expect(migration).to receive(:sleep).with(30).twice

        expect do
          migrate
        end.to raise_error(error_class)
      end
    end
  end
end
