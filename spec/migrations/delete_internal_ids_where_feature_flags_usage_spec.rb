# frozen_string_literal: true

require 'spec_helper'
require Rails.root.join('db', 'post_migrate', '20200117194900_delete_internal_ids_where_feature_flags_usage')

describe DeleteInternalIdsWhereFeatureFlagsUsage, :migration do
  let(:namespaces)   { table(:namespaces) }
  let(:projects)     { table(:projects) }
  let(:internal_ids) { table(:internal_ids) }

  def setup
    namespace = namespaces.create!(name: 'foo', path: 'foo')
    project = projects.create!(namespace_id: namespace.id)

    project
  end

  it 'deletes feature flag rows from the internal_ids table' do
    project = setup
    internal_ids.create!(project_id: project.id, usage: 6, last_value: 1)

    disable_migrations_output { migrate! }

    expect(internal_ids.count).to eq(0)
  end

  it 'does not delete issue rows from the internal_ids table' do
    project = setup
    internal_ids.create!(project_id: project.id, usage: 0, last_value: 1)

    disable_migrations_output { migrate! }

    expect(internal_ids.count).to eq(1)
  end

  it 'does not delete merge request rows from the internal_ids table' do
    project = setup
    internal_ids.create!(project_id: project.id, usage: 1, last_value: 1)

    disable_migrations_output { migrate! }

    expect(internal_ids.count).to eq(1)
  end
end
