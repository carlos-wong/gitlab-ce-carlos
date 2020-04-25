# frozen_string_literal: true

class RemoveProjectIdIndexOnLfsObjectsProjects < ActiveRecord::Migration[5.2]
  include Gitlab::Database::MigrationHelpers

  DOWNTIME = false

  disable_ddl_transaction!

  def up
    remove_concurrent_index :lfs_objects_projects, :project_id
  end

  def down
    add_concurrent_index :lfs_objects_projects, :project_id
  end
end
