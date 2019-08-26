# frozen_string_literal: true

class RenameAllowLocalRequestsFromHooksAndServicesApplicationSetting < ActiveRecord::Migration[5.2]
  include Gitlab::Database::MigrationHelpers

  DOWNTIME = false

  disable_ddl_transaction!

  def up
    rename_column_concurrently :application_settings, :allow_local_requests_from_hooks_and_services, :allow_local_requests_from_web_hooks_and_services
  end

  def down
    cleanup_concurrent_column_rename :application_settings, :allow_local_requests_from_web_hooks_and_services, :allow_local_requests_from_hooks_and_services
  end
end
