# frozen_string_literal: true

# See http://doc.gitlab.com/ce/development/migration_style_guide.html
# for more information on how to write migrations for GitLab.

class AddOptionsToBuildMetadata < ActiveRecord::Migration[5.0]
  include Gitlab::Database::MigrationHelpers

  DOWNTIME = false

  def change
    add_column :ci_builds_metadata, :config_options, :jsonb
    add_column :ci_builds_metadata, :config_variables, :jsonb
  end
end
