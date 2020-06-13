# frozen_string_literal: true

class RequirementsAddProjectFk < ActiveRecord::Migration[6.0]
  include Gitlab::Database::MigrationHelpers

  DOWNTIME = false

  def up
    with_lock_retries do
      add_foreign_key(:requirements, :projects, column: :project_id, on_delete: :cascade) # rubocop: disable Migration/AddConcurrentForeignKey
    end
  end

  def down
    with_lock_retries do
      remove_foreign_key(:requirements, column: :project_id)
    end
  end
end
