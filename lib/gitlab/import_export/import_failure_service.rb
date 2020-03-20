# frozen_string_literal: true

module Gitlab
  module ImportExport
    class ImportFailureService
      RETRIABLE_EXCEPTIONS = [GRPC::DeadlineExceeded, ActiveRecord::QueryCanceled].freeze

      attr_reader :importable

      def initialize(importable)
        @importable = importable
        @association = importable.association(:import_failures)
      end

      def with_retry(relation_key, relation_index)
        on_retry = -> (exception, retry_count, *_args) do
          log_import_failure(relation_key, relation_index, exception, retry_count)
        end

        Retriable.with_context(:relation_import, on_retry: on_retry) do
          yield
        end
      end

      def log_import_failure(relation_key, relation_index, exception, retry_count = 0)
        extra = {
          relation_key: relation_key,
          relation_index: relation_index,
          retry_count: retry_count
        }
        extra[importable_column_name] = importable.id

        Gitlab::ErrorTracking.track_exception(exception, extra)

        attributes = {
          exception_class: exception.class.to_s,
          exception_message: exception.message.truncate(255),
          correlation_id_value: Labkit::Correlation::CorrelationId.current_or_new_id
        }.merge(extra)

        ImportFailure.create(attributes)
      end

      private

      def importable_column_name
        @importable_column_name ||= @association.reflection.foreign_key.to_sym
      end
    end
  end
end
