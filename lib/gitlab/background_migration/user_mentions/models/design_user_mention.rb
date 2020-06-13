# frozen_string_literal: true
# rubocop:disable Style/Documentation

module Gitlab
  module BackgroundMigration
    module UserMentions
      module Models
        class DesignUserMention < ActiveRecord::Base
          self.table_name = 'design_user_mentions'

          def self.resource_foreign_key
            :design_id
          end
        end
      end
    end
  end
end
