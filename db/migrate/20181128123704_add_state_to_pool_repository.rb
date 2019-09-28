# frozen_string_literal: true

class AddStateToPoolRepository < ActiveRecord::Migration[5.0]
  include Gitlab::Database::MigrationHelpers

  DOWNTIME = false

  # Given the table is empty, and the non concurrent methods are chosen so
  # the transactions don't have to be disabled
  # rubocop: disable Migration/AddConcurrentForeignKey, Migration/AddIndex
  def change
    add_column(:pool_repositories, :state, :string, null: true) # rubocop:disable Migration/AddLimitToStringColumns

    add_column :pool_repositories, :source_project_id, :integer
    add_index :pool_repositories, :source_project_id, unique: true
    add_foreign_key :pool_repositories, :projects, column: :source_project_id, on_delete: :nullify
  end
  # rubocop: enable Migration/AddConcurrentForeignKey, Migration/AddIndex
end
