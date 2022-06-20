# frozen_string_literal: true
#
# Query a recursively defined namespace hierarchy using linear methods through
# the traversal_ids attribute.
#
# Namespace is a nested hierarchy of one parent to many children. A search
# using only the parent-child relationships is a slow operation. This process
# was previously optimized using Postgresql recursive common table expressions
# (CTE) with acceptable performance. However, it lead to slower than possible
# performance, and resulted in complicated queries that were difficult to make
# performant.
#
# Instead of searching the hierarchy recursively, we store a `traversal_ids`
# attribute on each node. The `traversal_ids` is an ordered array of Namespace
# IDs that define the traversal path from the root Namespace to the current
# Namespace.
#
# For example, suppose we have the following Namespaces:
#
# GitLab (id: 1) > Engineering (id: 2) > Manage (id: 3) > Access (id: 4)
#
# Then `traversal_ids` for group "Access" is [1, 2, 3, 4]
#
# And we can match against other Namespace `traversal_ids` such that:
#
# - Ancestors are [1], [1, 2], [1, 2, 3]
# - Descendants are [1, 2, 3, 4, *]
# - Root is [1]
# - Hierarchy is [1, *]
#
# Note that this search method works so long as the IDs are unique and the
# traversal path is ordered from root to leaf nodes.
#
# We implement this in the database using Postgresql arrays, indexed by a
# generalized inverted index (gin).
module Namespaces
  module Traversal
    module Linear
      extend ActiveSupport::Concern
      include LinearScopes

      UnboundedSearch = Class.new(StandardError)

      included do
        before_update :lock_both_roots, if: -> { sync_traversal_ids? && parent_id_changed? }
        after_update :sync_traversal_ids, if: -> { sync_traversal_ids? && saved_change_to_parent_id? }
        # This uses rails internal before_commit API to sync traversal_ids on namespace create, right before transaction is committed.
        # This helps reduce the time during which the root namespace record is locked to ensure updated traversal_ids are valid
        before_commit :sync_traversal_ids, on: [:create], if: -> { sync_traversal_ids? }
      end

      class_methods do
        # This method looks into a list of namespaces trying to optimise a returned traversal_ids
        # into a list of shortest prefixes, due to fact that the shortest prefixes include all childrens.
        # Example:
        # INPUT: [[4909902], [4909902,51065789], [4909902,51065793], [7135830], [15599674, 1], [15599674, 1, 3], [15599674, 2]]
        # RESULT: [[4909902], [7135830], [15599674, 1], [15599674, 2]]
        def shortest_traversal_ids_prefixes
          raise ArgumentError, 'Feature not supported since the `:use_traversal_ids` is disabled' unless use_traversal_ids?

          prefixes = []

          # The array needs to be sorted (O(nlogn)) to ensure shortest elements are always first
          # This allows to do O(n) search of shortest prefixes
          all_traversal_ids = all.order('namespaces.traversal_ids').pluck('namespaces.traversal_ids')
          last_prefix = [nil]

          all_traversal_ids.each do |traversal_ids|
            next if last_prefix == traversal_ids[0..(last_prefix.count - 1)]

            last_prefix = traversal_ids
            prefixes << traversal_ids
          end

          prefixes
        end
      end

      def sync_traversal_ids?
        Feature.enabled?(:sync_traversal_ids, root_ancestor, default_enabled: :yaml)
      end

      def use_traversal_ids?
        return false unless Feature.enabled?(:use_traversal_ids, default_enabled: :yaml)

        traversal_ids.present?
      end

      def use_traversal_ids_for_self_and_hierarchy?
        return false unless use_traversal_ids?
        return false unless Feature.enabled?(:use_traversal_ids_for_self_and_hierarchy, root_ancestor, default_enabled: :yaml)

        traversal_ids.present?
      end

      def use_traversal_ids_for_ancestors?
        return false unless use_traversal_ids?
        return false unless Feature.enabled?(:use_traversal_ids_for_ancestors, root_ancestor, default_enabled: :yaml)

        traversal_ids.present?
      end

      def use_traversal_ids_for_ancestors_upto?
        return false unless use_traversal_ids?
        return false unless Feature.enabled?(:use_traversal_ids_for_ancestors_upto, root_ancestor, default_enabled: :yaml)

        traversal_ids.present?
      end

      def use_traversal_ids_for_root_ancestor?
        return false unless Feature.enabled?(:use_traversal_ids_for_root_ancestor, default_enabled: :yaml)

        traversal_ids.present?
      end

      def root_ancestor
        return super unless use_traversal_ids_for_root_ancestor?

        strong_memoize(:root_ancestor) do
          if parent_id.nil?
            self
          else
            Namespace.find_by(id: traversal_ids.first)
          end
        end
      end

      def self_and_descendants
        return super unless use_traversal_ids?

        lineage(top: self)
      end

      def self_and_descendant_ids
        return super unless use_traversal_ids?

        self_and_descendants.as_ids
      end

      def descendants
        return super unless use_traversal_ids?

        self_and_descendants.where.not(id: id)
      end

      def self_and_hierarchy
        return super unless use_traversal_ids_for_self_and_hierarchy?

        self_and_descendants.or(ancestors)
      end

      def ancestors(hierarchy_order: nil)
        return super unless use_traversal_ids_for_ancestors?

        return self.class.none if parent_id.blank?

        lineage(bottom: parent, hierarchy_order: hierarchy_order)
      end

      def ancestor_ids(hierarchy_order: nil)
        return super unless use_traversal_ids_for_ancestors?

        hierarchy_order == :desc ? traversal_ids[0..-2] : traversal_ids[0..-2].reverse
      end

      # Returns all ancestors upto but excluding the top.
      # When no top is given, all ancestors are returned.
      # When top is not found, returns all ancestors.
      #
      # This copies the behavior of the recursive method. We will deprecate
      # this behavior soon.
      def ancestors_upto(top = nil, hierarchy_order: nil)
        return super unless use_traversal_ids_for_ancestors_upto?

        # We can't use a default value in the method definition above because
        # we need to preserve those specific parameters for super.
        hierarchy_order ||= :desc

        # Get all ancestor IDs inclusively between top and our parent.
        top_index = top ? traversal_ids.find_index(top.id) : 0
        ids = traversal_ids[top_index...-1]
        ids_string = ids.map { |id| Integer(id) }.join(',')

        # WITH ORDINALITY lets us order the result to match traversal_ids order.
        from_sql = <<~SQL
          unnest(ARRAY[#{ids_string}]::bigint[]) WITH ORDINALITY AS ancestors(id, ord)
          INNER JOIN namespaces ON namespaces.id = ancestors.id
        SQL

        self.class
          .from(Arel.sql(from_sql))
          .order('ancestors.ord': hierarchy_order)
      end

      def self_and_ancestors(hierarchy_order: nil)
        return super unless use_traversal_ids_for_ancestors?

        return self.class.where(id: id) if parent_id.blank?

        lineage(bottom: self, hierarchy_order: hierarchy_order)
      end

      def self_and_ancestor_ids(hierarchy_order: nil)
        return super unless use_traversal_ids_for_ancestors?

        hierarchy_order == :desc ? traversal_ids : traversal_ids.reverse
      end

      private

      # Update the traversal_ids for the full hierarchy.
      #
      # NOTE: self.traversal_ids will be stale. Reload for a fresh record.
      def sync_traversal_ids
        # Clear any previously memoized root_ancestor as our ancestors have changed.
        clear_memoization(:root_ancestor)

        Namespace::TraversalHierarchy.for_namespace(self).sync_traversal_ids!
      end

      # Lock the root of the hierarchy we just left, and lock the root of the hierarchy
      # we just joined. In most cases the two hierarchies will be the same.
      def lock_both_roots
        parent_ids = [
          parent_id_was || self.id,
          parent_id || self.id
        ].compact

        roots = Gitlab::ObjectHierarchy
          .new(Namespace.where(id: parent_ids))
          .base_and_ancestors
          .reorder(nil)
          .where(parent_id: nil)

        Namespace.lock.select(:id).where(id: roots).order(id: :asc).load
      end

      # Search this namespace's lineage. Bound inclusively by top node.
      def lineage(top: nil, bottom: nil, hierarchy_order: nil)
        raise UnboundedSearch, 'Must bound search by either top or bottom' unless top || bottom

        skope = self.class

        if top
          skope = skope.where("traversal_ids @> ('{?}')", top.id)
        end

        if bottom
          skope = skope.where(id: bottom.traversal_ids)
        end

        # The original `with_depth` attribute in ObjectHierarchy increments as you
        # walk away from the "base" namespace. This direction changes depending on
        # if you are walking up the ancestors or down the descendants.
        if hierarchy_order
          depth_sql = "ABS(#{traversal_ids.count} - array_length(traversal_ids, 1))"
          skope = skope.select(skope.default_select_columns, "#{depth_sql} as depth")
          # The SELECT includes an extra depth attribute. We wrap the SQL in a
          # standard SELECT to avoid mismatched attribute errors when trying to
          # chain future ActiveRelation commands, and retain the ordering.
          skope = self.class
            .from(skope, self.class.table_name)
            .select(skope.arel_table[Arel.star])
            .order(depth: hierarchy_order)
        end

        skope
      end
    end
  end
end
