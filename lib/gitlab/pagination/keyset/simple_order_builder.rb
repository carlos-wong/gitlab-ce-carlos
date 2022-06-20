# frozen_string_literal: true

module Gitlab
  module Pagination
    module Keyset
      # This class transforms the `order()` values from an Activerecord scope into a
      # Gitlab::Pagination::Keyset::Order instance so the query later can be  used in
      # keyset pagination.
      #
      # Return values:
      # [transformed_scope, true] # true indicates that the new scope was successfully built
      # [orginal_scope, false] # false indicates that the order values are not supported in this class
      class SimpleOrderBuilder
        NULLS_ORDER_REGEX = /(?<column_name>.*) (?<direction>\bASC\b|\bDESC\b) (?<nullable>\bNULLS LAST\b|\bNULLS FIRST\b)/.freeze

        def self.build(scope)
          new(scope: scope).build
        end

        def initialize(scope:)
          @scope = scope
          # We need to run 'compact' because 'nil' is not removed from order_values
          # in some cases due to the use of 'default_scope'.
          @order_values = scope.order_values.compact
          @model_class = scope.model
          @arel_table = @model_class.arel_table
          @primary_key = @model_class.primary_key
        end

        def build
          order = if order_values.empty?
                    primary_key_descending_order
                  elsif Gitlab::Pagination::Keyset::Order.keyset_aware?(scope)
                    Gitlab::Pagination::Keyset::Order.extract_keyset_order_object(scope)
                  # Ordered by a primary key. Ex. 'ORDER BY id'.
                  elsif ordered_by_primary_key?
                    primary_key_order
                  # Ordered by one non-primary table column. Ex. 'ORDER BY created_at'.
                  elsif ordered_by_other_column?
                    column_with_tie_breaker_order
                  # Ordered by two table columns with the last column as a tie breaker. Ex. 'ORDER BY created, id ASC'.
                  elsif ordered_by_other_column_with_tie_breaker?
                    tie_breaker_attribute = order_values.second

                    tie_breaker_column_order = Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
                      attribute_name: model_class.primary_key,
                      order_expression: tie_breaker_attribute
                    )

                    column_with_tie_breaker_order(tie_breaker_column_order)
                  end

          order ? [scope.reorder!(order), true] : [scope, false] # [scope, success]
        end

        private

        attr_reader :scope, :order_values, :model_class, :arel_table, :primary_key

        def table_column?(name)
          model_class.column_names.include?(name.to_s)
        end

        def primary_key?(attribute)
          arel_table[primary_key].to_s == attribute.to_s
        end

        def lower_named_function?(attribute)
          attribute.is_a?(Arel::Nodes::NamedFunction) && attribute.name&.downcase == 'lower'
        end

        def arel_nulls?(order_value)
          return unless order_value.is_a?(Arel::Nodes::NullsLast) || order_value.is_a?(Arel::Nodes::NullsFirst)

          column_name = order_value.try(:expr).try(:expr).try(:name)

          table_column?(column_name)
        end

        def supported_column?(order_value)
          return true if arel_nulls?(order_value)

          attribute = order_value.try(:expr)
          return unless attribute

          if lower_named_function?(attribute)
            attribute.expressions.one? && attribute.expressions.first.respond_to?(:name) && table_column?(attribute.expressions.first.name)
          else
            attribute.respond_to?(:name) && table_column?(attribute.name)
          end
        end

        # This method converts the first order value to a corresponding arel expression
        # if the order value uses either NULLS LAST or NULLS FIRST ordering in raw SQL.
        #
        # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/356644
        # We should stop matching raw literals once we switch to using the Arel methods.
        def convert_raw_nulls_order!
          order_value = order_values.first

          return unless order_value.is_a?(Arel::Nodes::SqlLiteral)

          # Detect NULLS LAST or NULLS FIRST ordering by looking at the raw SQL string.
          if matches = order_value.match(NULLS_ORDER_REGEX)
            return unless table_column?(matches[:column_name])

            column_attribute = arel_table[matches[:column_name]]
            direction = matches[:direction].downcase.to_sym
            nullable = matches[:nullable].downcase.parameterize(separator: '_').to_sym

            # Build an arel order expression for NULLS ordering.
            order = direction == :desc ? column_attribute.desc : column_attribute.asc
            arel_order_expression = nullable == :nulls_first ? order.nulls_first : order.nulls_last

            order_values[0] = arel_order_expression
          end
        end

        def nullability(order_value, attribute_name)
          nullable = model_class.columns.find { |column| column.name == attribute_name }.null

          if nullable && order_value.is_a?(Arel::Nodes::Ascending)
            :nulls_last
          elsif nullable && order_value.is_a?(Arel::Nodes::Descending)
            :nulls_first
          else
            :not_nullable
          end
        end

        def primary_key_descending_order
          Gitlab::Pagination::Keyset::Order.build([
            Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
              attribute_name: model_class.primary_key,
              order_expression: arel_table[primary_key].desc
            )
          ])
        end

        def primary_key_order
          Gitlab::Pagination::Keyset::Order.build([
            Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
              attribute_name: model_class.primary_key,
              order_expression: order_values.first
            )
          ])
        end

        def column_with_tie_breaker_order(tie_breaker_column_order = default_tie_breaker_column_order)
          Gitlab::Pagination::Keyset::Order.build([
            column(order_values.first),
            tie_breaker_column_order
          ])
        end

        def column(order_value)
          return nulls_order_column(order_value) if arel_nulls?(order_value)
          return lower_named_function_column(order_value) if lower_named_function?(order_value.expr)

          attribute_name = order_value.expr.name

          Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
            attribute_name: attribute_name,
            order_expression: order_value,
            nullable: nullability(order_value, attribute_name),
            distinct: false
          )
        end

        def nulls_order_column(order_value)
          attribute = order_value.expr.expr

          Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
            attribute_name: attribute.name,
            column_expression: attribute,
            order_expression: order_value,
            reversed_order_expression: order_value.reverse,
            order_direction: order_value.expr.direction,
            nullable: order_value.is_a?(Arel::Nodes::NullsLast) ? :nulls_last : :nulls_first,
            distinct: false
          )
        end

        def lower_named_function_column(order_value)
          attribute_name = order_value.expr.expressions.first.name

          Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
            attribute_name: attribute_name,
            column_expression: Arel::Nodes::NamedFunction.new("LOWER", [model_class.arel_table[attribute_name]]),
            order_expression: order_value,
            nullable: nullability(order_value, attribute_name),
            distinct: false
          )
        end

        def ordered_by_primary_key?
          return unless order_values.one?

          attribute = order_values.first.try(:expr)
          attribute && primary_key?(attribute)
        end

        def ordered_by_other_column?
          return unless order_values.one?

          convert_raw_nulls_order!

          supported_column?(order_values.first)
        end

        def ordered_by_other_column_with_tie_breaker?
          return unless order_values.size == 2

          convert_raw_nulls_order!

          return unless supported_column?(order_values.first)

          tie_breaker_attribute = order_values.second.try(:expr)
          tie_breaker_attribute && primary_key?(tie_breaker_attribute)
        end

        def default_tie_breaker_column_order
          Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
            attribute_name: model_class.primary_key,
            order_expression: arel_table[primary_key].desc
          )
        end
      end
    end
  end
end
