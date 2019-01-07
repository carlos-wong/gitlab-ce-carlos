class ImportCommonMetricsNginxVts < ActiveRecord::Migration[5.0]
  include Gitlab::Database::MigrationHelpers

  require Rails.root.join('db/importers/common_metrics_importer.rb')

  DOWNTIME = false

  def up
    Importers::CommonMetricsImporter.new.execute
  end

  def down
    # no-op
  end
end
