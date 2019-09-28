class CreateDeployTokens < ActiveRecord::Migration[4.2]
  DOWNTIME = false

  def change
    # rubocop:disable Migration/AddLimitToStringColumns
    create_table :deploy_tokens do |t|
      t.boolean :revoked, default: false
      t.boolean :read_repository, null: false, default: false
      t.boolean :read_registry, null: false, default: false

      t.datetime_with_timezone :expires_at, null: false
      t.datetime_with_timezone :created_at, null: false

      t.string :name, null: false
      t.string :token, index: { unique: true }, null: false

      t.index [:token, :expires_at, :id], where: "(revoked IS FALSE)"
    end
    # rubocop:enable Migration/AddLimitToStringColumns
  end
end
