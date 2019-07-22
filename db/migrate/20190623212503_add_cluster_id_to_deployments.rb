# frozen_string_literal: true

class AddClusterIdToDeployments < ActiveRecord::Migration[5.1]
  DOWNTIME = false

  def change
    add_column :deployments, :cluster_id, :integer
  end
end
