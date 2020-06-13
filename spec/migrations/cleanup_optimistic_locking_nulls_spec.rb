# frozen_string_literal: true

require 'spec_helper'
require Rails.root.join('db', 'post_migrate', '20200128210353_cleanup_optimistic_locking_nulls')

describe CleanupOptimisticLockingNulls do
  TABLES = %w(epics merge_requests issues).freeze
  TABLES.each do |table|
    let(table.to_sym) { table(table.to_sym) }
  end
  let(:tables) { TABLES.map { |t| method(t.to_sym).call } }

  let(:namespaces) { table(:namespaces) }
  let(:projects) { table(:projects) }
  let(:users) { table(:users)}

  before do
    namespaces.create!(id: 123, name: 'gitlab1', path: 'gitlab1')
    projects.create!(id: 123, name: 'gitlab1', path: 'gitlab1', namespace_id: 123)
    users.create!(id: 123, username: 'author', projects_limit: 1000)

    # Create necessary rows
    epics.create!(iid: 123, group_id: 123, author_id: 123, title: 'a', title_html: 'a')
    merge_requests.create!(iid: 123, target_project_id: 123, source_project_id: 123, target_branch: 'master', source_branch: 'hmm', title: 'a', title_html: 'a')
    issues.create!(iid: 123, project_id: 123, title: 'a', title_html: 'a')

    # Nullify `lock_version` column for all rows
    # Needs to be done with a SQL fragment, otherwise Rails will coerce it to 0
    tables.each do |table|
      table.update_all('lock_version = NULL')
    end
  end

  it 'correctly migrates nullified lock_version column', :sidekiq_inline do
    tables.each do |table|
      expect(table.where(lock_version: nil).count).to eq(1)
    end

    tables.each do |table|
      expect(table.where(lock_version: 0).count).to eq(0)
    end

    migrate!

    tables.each do |table|
      expect(table.where(lock_version: nil).count).to eq(0)
    end

    tables.each do |table|
      expect(table.where(lock_version: 0).count).to eq(1)
    end
  end
end
