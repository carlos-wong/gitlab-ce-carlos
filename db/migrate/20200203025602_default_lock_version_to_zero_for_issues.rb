# frozen_string_literal: true

# See http://doc.gitlab.com/ce/development/migration_style_guide.html
# for more information on how to write migrations for GitLab.

class DefaultLockVersionToZeroForIssues < ActiveRecord::Migration[6.0]
  include Gitlab::Database::MigrationHelpers

  # Set this constant to true if this migration requires downtime.
  DOWNTIME = false

  def change
    with_lock_retries do
      change_column_default :issues, :lock_version, from: nil, to: 0
    end
  end
end
