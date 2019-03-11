# frozen_string_literal: true

class AddHeaderAndFooterBannersToAppearancesTable < ActiveRecord::Migration[4.2]
  include Gitlab::Database::MigrationHelpers

  DOWNTIME = false

  def change
    add_column :appearances, :header_message, :text
    add_column :appearances, :header_message_html, :text

    add_column :appearances, :footer_message, :text
    add_column :appearances, :footer_message_html, :text

    add_column :appearances, :message_background_color, :text
    add_column :appearances, :message_font_color, :text
  end
end
