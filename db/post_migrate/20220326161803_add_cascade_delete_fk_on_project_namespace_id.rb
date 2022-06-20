# frozen_string_literal: true

class AddCascadeDeleteFkOnProjectNamespaceId < Gitlab::Database::Migration[1.0]
  disable_ddl_transaction!

  TARGET_COLUMN = :project_namespace_id

  def up
    # add the new FK before removing the old one
    add_concurrent_foreign_key(
      :projects,
      :namespaces,
      column: TARGET_COLUMN,
      name: fk_name("#{TARGET_COLUMN}_new"),
      on_delete: :cascade
    )

    with_lock_retries do
      remove_foreign_key_if_exists(:projects, column: TARGET_COLUMN, name: fk_name(TARGET_COLUMN))
    end
  end

  def down
    add_concurrent_foreign_key(
      :projects,
      :namespaces,
      column: TARGET_COLUMN,
      name: fk_name(TARGET_COLUMN),
      on_delete: :nullify
    )

    with_lock_retries do
      remove_foreign_key_if_exists(:projects, column: TARGET_COLUMN, name: fk_name("#{TARGET_COLUMN}_new"))
    end
  end

  def fk_name(column_name)
    # generate a FK name
    concurrent_foreign_key_name(:projects, column_name)
  end
end
