# frozen_string_literal: true

# See http://doc.gitlab.com/ce/development/migration_style_guide.html
# for more information on how to write migrations for GitLab.

class PrometheusKnative05Fix < ActiveRecord::Migration[5.0]
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
