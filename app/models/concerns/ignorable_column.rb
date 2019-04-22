# frozen_string_literal: true

# Module that can be included into a model to make it easier to ignore database
# columns.
#
# Example:
#
#     class User < ApplicationRecord
#       include IgnorableColumn
#
#       ignore_column :updated_at
#     end
#
module IgnorableColumn
  extend ActiveSupport::Concern

  class_methods do
    def columns
      super.reject { |column| ignored_columns.include?(column.name) }
    end

    def ignored_columns
      @ignored_columns ||= Set.new
    end

    def ignore_column(*names)
      ignored_columns.merge(names.map(&:to_s))
    end
  end
end
