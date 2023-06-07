# frozen_string_literal: true

module Gitlab
  module ImportExport
    module Json
      class StreamingSerializer
        include Gitlab::ImportExport::CommandLineUtil

        BATCH_SIZE = 100

        class Raw < String
          def to_json(*_args)
            to_s
          end
        end

        def initialize(exportable, relations_schema, json_writer, current_user:, exportable_path:, logger: Gitlab::Export::Logger)
          @exportable = exportable
          @current_user = current_user
          @exportable_path = exportable_path
          @relations_schema = relations_schema
          @json_writer = json_writer
          @logger = logger
        end

        def execute
          read_from_replica_if_available do
            serialize_root

            includes.each do |relation_definition|
              serialize_relation(relation_definition)
            end
          end
        end

        def serialize_root(exportable_path = @exportable_path)
          log_relation_export('root')

          attributes = exportable.as_json(
            relations_schema.merge(include: nil, preloads: nil, unsafe: true))

          json_writer.write_attributes(exportable_path, attributes)
        end

        def serialize_relation(definition)
          raise ArgumentError, 'definition needs to be Hash' unless definition.is_a?(Hash)
          raise ArgumentError, 'definition needs to have exactly one Hash element' unless definition.one?

          key, options = definition.first

          record = exportable.public_send(key) # rubocop: disable GitlabSecurity/PublicSend
          if record.is_a?(ActiveRecord::Relation)
            serialize_many_relations(key, record, options)
          elsif record.respond_to?(:each) # this is to support `project_members` that return an Array
            serialize_many_each(key, record, options)
          else
            serialize_single_relation(key, record, options)
          end
        end

        private

        attr_reader :json_writer, :relations_schema, :exportable, :logger, :current_user

        def serialize_many_relations(key, records, options)
          log_relation_export(key, records.size)

          enumerator = Enumerator.new do |items|
            key_preloads = preloads&.dig(key)

            batch(records, key) do |batch|
              batch = batch.preload(key_preloads) if key_preloads

              batch.each do |record|
                before_read_callback(record)

                items << exportable_json_record(record, options, key)

                after_read_callback(record)
              end
            end
          end

          json_writer.write_relation_array(@exportable_path, key, enumerator)
        end

        def exportable_json_record(record, options, key)
          return Raw.new(record.to_json(options)) unless options[:include].any?

          conditional_associations = relations_schema[:include_if_exportable]&.dig(key)

          filtered_options =
            if conditional_associations.present?
              filter_conditional_include(record, options, conditional_associations)
            else
              options
            end

          Raw.new(authorized_record_json(record, filtered_options))
        end

        def filter_conditional_include(record, options, conditional_associations)
          filtered_options = options.deep_dup

          conditional_associations.each do |association|
            filtered_options[:include].delete_if do |option|
              !exportable_json_association?(option, record, association.to_sym)
            end
          end

          filtered_options
        end

        def exportable_json_association?(option, record, association)
          return true unless option.has_key?(association)
          return false unless record.respond_to?(:exportable_association?)

          record.exportable_association?(association, current_user: current_user)
        end

        def authorized_record_json(record, options)
          include_keys = options[:include].flat_map(&:keys)
          keys_to_authorize = record.try(:restricted_associations, include_keys)

          return record.to_json(options) if keys_to_authorize.blank?

          record.to_authorized_json(keys_to_authorize, current_user, options)
        end

        def batch(relation, key)
          opts = { of: BATCH_SIZE }
          order_by = reorders(relation, key)

          # we need to sort issues by non primary key column(relative_position)
          # and `in_batches` does not support that
          if order_by
            scope = relation.reorder(order_by)

            Gitlab::Pagination::Keyset::Iterator.new(scope: scope, use_union_optimization: true).each_batch(**opts) do |batch|
              yield batch
            end
          else
            relation.in_batches(**opts) do |batch| # rubocop:disable Cop/InBatches
              # order each batch by its primary key to ensure
              # consistent and predictable ordering of each exported relation
              # as additional `WHERE` clauses can impact the order in which data is being
              # returned by database when no `ORDER` is specified
              yield batch.reorder(batch.klass.primary_key)
            end
          end
        end

        def serialize_many_each(key, records, options)
          log_relation_export(key, records.size)

          enumerator = Enumerator.new do |items|
            records.each do |record|
              items << exportable_json_record(record, options, key)
            end
          end

          json_writer.write_relation_array(@exportable_path, key, enumerator)
        end

        def serialize_single_relation(key, record, options)
          log_relation_export(key)

          json = exportable_json_record(record, options, key)

          json_writer.write_relation(@exportable_path, key, json)
        end

        def includes
          relations_schema[:include]
        end

        def preloads
          relations_schema[:preload]
        end

        def reorders(relation, key)
          export_reorder = relations_schema[:export_reorder]&.dig(key)
          return unless export_reorder

          custom_reorder(relation.klass, export_reorder)
        end

        def custom_reorder(klass, order_by)
          arel_table = klass.arel_table
          column = order_by[:column] || klass.primary_key
          direction = order_by[:direction] || :asc
          nulls_position = order_by[:nulls_position] || :nulls_last

          arel_order_classes = ::Gitlab::Pagination::Keyset::ColumnOrderDefinition::AREL_ORDER_CLASSES.invert
          reverse_direction = ::Gitlab::Pagination::Keyset::ColumnOrderDefinition::REVERSED_ORDER_DIRECTIONS[direction]
          reverse_nulls_position = ::Gitlab::Pagination::Keyset::ColumnOrderDefinition::REVERSED_NULL_POSITIONS[nulls_position]
          order_expression = arel_table[column].public_send(direction).public_send(nulls_position) # rubocop:disable GitlabSecurity/PublicSend
          reverse_order_expression = arel_table[column].public_send(reverse_direction).public_send(reverse_nulls_position) # rubocop:disable GitlabSecurity/PublicSend

          ::Gitlab::Pagination::Keyset::Order.build(
            [
              ::Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
                attribute_name: column,
                column_expression: arel_table[column],
                order_expression: order_expression,
                reversed_order_expression: reverse_order_expression,
                order_direction: direction,
                nullable: nulls_position,
                distinct: false
              ),
              ::Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
                attribute_name: klass.primary_key,
                order_expression: arel_order_classes[direction].new(arel_table[klass.primary_key.to_sym])
              )
            ])
        end

        def read_from_replica_if_available(&block)
          ::Gitlab::Database::LoadBalancing::Session.current.use_replicas_for_read_queries(&block)
        end

        def before_read_callback(record)
          remove_cached_external_diff(record)
        end

        def after_read_callback(record)
          remove_cached_external_diff(record)
        end

        def remove_cached_external_diff(record)
          return unless record.is_a?(MergeRequest)

          record.merge_request_diff&.remove_cached_external_diff
        end

        def log_base_data
          log = { importer: 'Import/Export' }
          log.merge!(Gitlab::ImportExport::LogUtil.exportable_to_log_payload(exportable))
          log
        end

        def log_relation_export(relation, size = nil)
          message = "Exporting #{relation} relation"
          message += ". Number of records to export: #{size}" if size
          logger.info(message: message, **log_base_data)
        end
      end
    end
  end
end
