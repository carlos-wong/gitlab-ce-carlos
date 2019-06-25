class AddIndexesToRemoteMirror < ActiveRecord::Migration[4.2]
  include Gitlab::Database::MigrationHelpers

  DOWNTIME = false

  disable_ddl_transaction!

  def up
    add_concurrent_index :remote_mirrors, :last_successful_update_at unless index_exists?(:remote_mirrors, :last_successful_update_at)
  end

  def down
    # ee/db/migrate/20170208144550_add_index_to_mirrors_last_update_at_fields.rb will remove the index.
    # rubocop:disable Migration/RemoveIndex
    remove_index :remote_mirrors, :last_successful_update_at if index_exists? :remote_mirrors, :last_successful_update_at
  end
end
