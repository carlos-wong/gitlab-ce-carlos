# frozen_string_literal: true

class QueueUpdateDelayedProjectRemovalToNullForUserNamespace < Gitlab::Database::Migration[2.0]
  MIGRATION = 'UpdateDelayedProjectRemovalToNullForUserNamespaces'
  INTERVAL = 2.minutes
  BATCH_SIZE = 10_000

  disable_ddl_transaction!

  restrict_gitlab_migration gitlab_schema: :gitlab_main

  def up
    queue_batched_background_migration(
      MIGRATION,
      :namespace_settings,
      :namespace_id,
      job_interval: INTERVAL,
      batch_size: BATCH_SIZE
    )
  end

  def down
    delete_batched_background_migration(MIGRATION, :namespace_settings, :namespace_id, [])
  end
end
