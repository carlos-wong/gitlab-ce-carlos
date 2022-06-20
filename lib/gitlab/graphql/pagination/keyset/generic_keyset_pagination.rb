# frozen_string_literal: true

module Gitlab
  module Graphql
    module Pagination
      module Keyset
        # https://gitlab.com/gitlab-org/gitlab/-/issues/334973
        # Use the generic keyset implementation if the given ActiveRecord scope supports it.
        # Note: this module is temporary, at some point it will be merged with Keyset::Connection
        module GenericKeysetPagination
          extend ActiveSupport::Concern

          # rubocop: disable Naming/PredicateName
          # rubocop: disable CodeReuse/ActiveRecord
          def has_next_page
            return super unless Gitlab::Pagination::Keyset::Order.keyset_aware?(items)

            strong_memoize(:generic_keyset_pagination_has_next_page) do
              if before
                true
              elsif first
                case sliced_nodes
                when Array
                  sliced_nodes.size > limit_value
                else
                  sliced_nodes.limit(1).offset(limit_value).exists?
                end
              else
                false
              end
            end
          end

          # rubocop: enable CodeReuse/ActiveRecord
          def ordered_items
            raise ArgumentError, 'Relation must have a primary key' unless items.primary_key.present?

            return super unless Gitlab::Pagination::Keyset::Order.keyset_aware?(items)

            items
          end

          def cursor_for(node)
            return super unless Gitlab::Pagination::Keyset::Order.keyset_aware?(items)

            order = Gitlab::Pagination::Keyset::Order.extract_keyset_order_object(items)
            encode(order.cursor_attributes_for_node(node).to_json)
          end

          def slice_nodes(sliced, encoded_cursor, before_or_after)
            return super unless Gitlab::Pagination::Keyset::Order.keyset_aware?(sliced)

            order = Gitlab::Pagination::Keyset::Order.extract_keyset_order_object(sliced)
            order = order.reversed_order if before_or_after == :before

            decoded_cursor = ordering_from_encoded_json(encoded_cursor)
            order.apply_cursor_conditions(sliced, decoded_cursor)
          end

          def sliced_nodes
            return super unless Gitlab::Pagination::Keyset::Order.keyset_aware?(items)

            sliced = ordered_items
            sliced = slice_nodes(sliced, before, :before) if before.present?
            sliced = slice_nodes(sliced, after, :after) if after.present?
            sliced
          end

          def items
            original_items = super
            return original_items if Feature.disabled?(:new_graphql_keyset_pagination, default_enabled: :yaml) || Gitlab::Pagination::Keyset::Order.keyset_aware?(original_items)

            strong_memoize(:generic_keyset_pagination_items) do
              rebuilt_items_with_keyset_order, success = Gitlab::Pagination::Keyset::SimpleOrderBuilder.build(original_items)

              if success
                rebuilt_items_with_keyset_order
              else
                if original_items.is_a?(ActiveRecord::Relation)
                  old_keyset_pagination_usage.increment({ model: original_items.model.to_s })
                end

                original_items
              end
            end
          end

          def old_keyset_pagination_usage
            @old_keyset_pagination_usage ||= Gitlab::Metrics.counter(
              :old_keyset_pagination_usage,
              'The number of times the old keyset pagination code was used'
            )
          end
        end
      end
    end
  end
end
