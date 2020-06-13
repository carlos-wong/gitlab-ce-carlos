# frozen_string_literal: true
# rubocop:disable Style/Documentation

module Gitlab
  module BackgroundMigration
    module UserMentions
      module Models
        class CommitUserMention < ActiveRecord::Base
          self.table_name = 'commit_user_mentions'

          def self.resource_foreign_key
            :commit_id
          end
        end
      end
    end
  end
end
