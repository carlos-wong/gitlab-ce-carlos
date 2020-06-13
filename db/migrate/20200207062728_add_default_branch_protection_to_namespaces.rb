# frozen_string_literal: true

class AddDefaultBranchProtectionToNamespaces < ActiveRecord::Migration[6.0]
  include Gitlab::Database::MigrationHelpers

  DOWNTIME = false

  def up
    with_lock_retries do
      add_column :namespaces, :default_branch_protection, :integer, limit: 2
    end
  end

  def down
    with_lock_retries do
      remove_column :namespaces, :default_branch_protection
    end
  end
end
