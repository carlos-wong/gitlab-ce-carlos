# frozen_string_literal: true

class RemoveForeignKeyInClustersIntegrationElasticstack < Gitlab::Database::Migration[2.0]
  disable_ddl_transaction!

  def up
    with_lock_retries do
      remove_foreign_key_if_exists(:clusters_integration_elasticstack, column: :cluster_id)
    end
  end

  def down
    add_concurrent_foreign_key :clusters_integration_elasticstack, :clusters,
      column: :cluster_id, on_delete: :cascade, name: 'fk_rails_cc5ba8f658'
  end
end
