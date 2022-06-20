# frozen_string_literal: true

module Ci
  # This model represents a record in a shadow table of the main database's namespaces table.
  # It allows us to navigate the namespace hierarchy on the ci database without resorting to a JOIN.
  class NamespaceMirror < ApplicationRecord
    include FromUnion

    belongs_to :namespace

    scope :by_group_and_descendants, -> (id) do
      where('traversal_ids @> ARRAY[?]::int[]', id)
    end

    scope :contains_any_of_namespaces, -> (ids) do
      where('traversal_ids && ARRAY[?]::int[]', ids)
    end

    scope :contains_traversal_ids, -> (traversal_ids) do
      mirrors = []

      traversal_ids.group_by(&:count).each do |columns_count, traversal_ids_group|
        columns = Array.new(columns_count) { |i| "(traversal_ids[#{i + 1}])" }
        pairs = traversal_ids_group.map do |ids|
          ids = ids.map { |id| Arel::Nodes.build_quoted(id).to_sql }
          "(#{ids.join(",")})"
        end

        # Create condition in format:
        # ((traversal_ids[1]),(traversal_ids[2])) IN ((1,2),(2,3))
        mirrors << Ci::NamespaceMirror.where("(#{columns.join(",")}) IN (#{pairs.join(",")})") # rubocop:disable GitlabSecurity/SqlInjection
      end

      self.from_union(mirrors)
    end

    scope :by_namespace_id, -> (namespace_id) { where(namespace_id: namespace_id) }

    class << self
      def sync!(event)
        namespace = event.namespace
        traversal_ids = namespace.self_and_ancestor_ids(hierarchy_order: :desc)

        upsert({ namespace_id: event.namespace_id, traversal_ids: traversal_ids },
               unique_by: :namespace_id)

        # It won't be necessary once we remove `sync_traversal_ids`.
        # More info: https://gitlab.com/gitlab-org/gitlab/-/issues/347541
        sync_children_namespaces!(event.namespace_id, traversal_ids)
      end

      private

      def sync_children_namespaces!(namespace_id, traversal_ids)
        by_group_and_descendants(namespace_id)
          .where.not(namespace_id: namespace_id)
          .update_all(
            "traversal_ids = ARRAY[#{sanitize_sql(traversal_ids.join(','))}]::int[] || traversal_ids[array_position(traversal_ids, #{sanitize_sql(namespace_id)}) + 1:]"
          )
      end
    end
  end
end
