# frozen_string_literal: true

class AddEncryptedRunnersTokenToProjects < ActiveRecord::Migration[4.2]
  include Gitlab::Database::MigrationHelpers

  DOWNTIME = false

  def change
    add_column :projects, :runners_token_encrypted, :string
  end
end
