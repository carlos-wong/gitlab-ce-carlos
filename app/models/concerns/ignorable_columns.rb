# frozen_string_literal: true

module IgnorableColumns
  extend ActiveSupport::Concern

  ColumnIgnore = Struct.new(:remove_after, :remove_with) do
    def safe_to_remove?
      Date.today > remove_after
    end

    def to_s
      "(#{remove_after}, #{remove_with})"
    end
  end

  class_methods do
    # Ignore database columns in a model
    #
    # Indicate the earliest date and release we can stop ignoring the column with +remove_after+ (a date string) and +remove_with+ (a release)
    def ignore_columns(*columns, remove_after:, remove_with:)
      raise ArgumentError, 'Please indicate when we can stop ignoring columns with remove_after (date string YYYY-MM-DD), example: ignore_columns(:name, remove_after: \'2019-12-01\', remove_with: \'12.6\')' unless remove_after =~ Gitlab::Regex.utc_date_regex
      raise ArgumentError, 'Please indicate in which release we can stop ignoring columns with remove_with, example: ignore_columns(:name, remove_after: \'2019-12-01\', remove_with: \'12.6\')' unless remove_with

      self.ignored_columns += columns.flatten # rubocop:disable Cop/IgnoredColumns

      columns.flatten.each do |column|
        self.ignored_columns_details[column.to_sym] = ColumnIgnore.new(Date.parse(remove_after), remove_with)
      end
    end

    alias_method :ignore_column, :ignore_columns

    def ignored_columns_details
      unless defined?(@ignored_columns_details)
        IGNORE_COLUMN_MUTEX.synchronize do
          @ignored_columns_details ||= superclass.try(:ignored_columns_details)&.dup || {}
        end
      end

      @ignored_columns_details
    end

    IGNORE_COLUMN_MUTEX = Mutex.new
  end
end
