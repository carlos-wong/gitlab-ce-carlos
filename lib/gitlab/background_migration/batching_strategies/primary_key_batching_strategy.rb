# frozen_string_literal: true

module Gitlab
  module BackgroundMigration
    module BatchingStrategies
      # Generic batching class for use with a BatchedBackgroundMigration.
      # Batches over the given table and column combination, returning the MIN() and MAX()
      # values for the next batch as an array.
      #
      # If no more batches exist in the table, returns nil.
      class PrimaryKeyBatchingStrategy < BaseStrategy
        include Gitlab::Database::DynamicModelHelpers

        # Finds and returns the next batch in the table.
        #
        # table_name - The table to batch over
        # column_name - The column to batch over
        # batch_min_value - The minimum value which the next batch will start at
        # batch_size - The size of the next batch
        # job_arguments - The migration job arguments
        def next_batch(table_name, column_name, batch_min_value:, batch_size:, job_arguments:)
          model_class = define_batchable_model(table_name, connection: connection)

          quoted_column_name = model_class.connection.quote_column_name(column_name)
          relation = model_class.where("#{quoted_column_name} >= ?", batch_min_value)
          relation = apply_additional_filters(relation, job_arguments: job_arguments)
          next_batch_bounds = nil

          relation.each_batch(of: batch_size, column: column_name) do |batch| # rubocop:disable Lint/UnreachableLoop
            next_batch_bounds = batch.pluck(Arel.sql("MIN(#{quoted_column_name}), MAX(#{quoted_column_name})")).first

            break
          end

          next_batch_bounds
        end

        # Strategies based on PrimaryKeyBatchingStrategy can use
        # this method to easily apply additional filters.
        #
        # Example:
        #
        #   class MatchingType < PrimaryKeyBatchingStrategy
        #     def apply_additional_filters(relation, job_arguments:)
        #       type = job_arguments.first
        #
        #       relation.where(type: type)
        #     end
        #   end
        def apply_additional_filters(relation, job_arguments: [])
          relation
        end
      end
    end
  end
end
