# frozen_string_literal: true

class AddVariableTypeToCiGroupVariables < ActiveRecord::Migration[5.0]
  include Gitlab::Database::MigrationHelpers
  disable_ddl_transaction!

  DOWNTIME = false
  ENV_VAR_VARIABLE_TYPE = 1

  def up
    add_column_with_default(:ci_group_variables, :variable_type, :smallint, default: ENV_VAR_VARIABLE_TYPE)
  end

  def down
    remove_column(:ci_group_variables, :variable_type)
  end
end
