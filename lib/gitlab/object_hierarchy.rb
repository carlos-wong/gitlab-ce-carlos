# frozen_string_literal: true

module Gitlab
  # Retrieving of parent or child objects based on a base ActiveRecord relation.
  #
  # This class uses recursive CTEs and as a result will only work on PostgreSQL.
  class ObjectHierarchy
    attr_reader :ancestors_base, :descendants_base, :model

    # ancestors_base - An instance of ActiveRecord::Relation for which to
    #                  get parent objects.
    # descendants_base - An instance of ActiveRecord::Relation for which to
    #                    get child objects. If omitted, ancestors_base is used.
    def initialize(ancestors_base, descendants_base = ancestors_base)
      raise ArgumentError.new("Model of ancestors_base does not match model of descendants_base") if ancestors_base.model != descendants_base.model

      @ancestors_base = ancestors_base
      @descendants_base = descendants_base
      @model = ancestors_base.model
    end

    # Returns the set of descendants of a given relation, but excluding the given
    # relation
    # rubocop: disable CodeReuse/ActiveRecord
    def descendants
      base_and_descendants.where.not(id: descendants_base.select(:id))
    end
    # rubocop: enable CodeReuse/ActiveRecord

    # Returns the set of ancestors of a given relation, but excluding the given
    # relation
    #
    # Passing an `upto` will stop the recursion once the specified parent_id is
    # reached. So all ancestors *lower* than the specified ancestor will be
    # included.
    # rubocop: disable CodeReuse/ActiveRecord
    def ancestors(upto: nil, hierarchy_order: nil)
      base_and_ancestors(upto: upto, hierarchy_order: hierarchy_order).where.not(id: ancestors_base.select(:id))
    end
    # rubocop: enable CodeReuse/ActiveRecord

    # Returns a relation that includes the ancestors_base set of objects
    # and all their ancestors (recursively).
    #
    # Passing an `upto` will stop the recursion once the specified parent_id is
    # reached. So all ancestors *lower* than the specified acestor will be
    # included.
    #
    # Passing a `hierarchy_order` with either `:asc` or `:desc` will cause the
    # recursive query order from most nested object to root or from the root
    # ancestor to most nested object respectively. This uses a `depth` column
    # where `1` is defined as the depth for the base and increment as we go up
    # each parent.
    # rubocop: disable CodeReuse/ActiveRecord
    def base_and_ancestors(upto: nil, hierarchy_order: nil)
      return ancestors_base unless hierarchy_supported?

      recursive_query = base_and_ancestors_cte(upto, hierarchy_order).apply_to(model.all)
      recursive_query = recursive_query.order(depth: hierarchy_order) if hierarchy_order

      read_only(recursive_query)
    end
    # rubocop: enable CodeReuse/ActiveRecord

    # Returns a relation that includes the descendants_base set of objects
    # and all their descendants (recursively).
    def base_and_descendants
      return descendants_base unless hierarchy_supported?

      read_only(base_and_descendants_cte.apply_to(model.all))
    end

    # Returns a relation that includes the base objects, their ancestors,
    # and the descendants of the base objects.
    #
    # The resulting query will roughly look like the following:
    #
    #     WITH RECURSIVE ancestors AS ( ... ),
    #       descendants AS ( ... )
    #     SELECT *
    #     FROM (
    #       SELECT *
    #       FROM ancestors namespaces
    #
    #       UNION
    #
    #       SELECT *
    #       FROM descendants namespaces
    #     ) groups;
    #
    # Using this approach allows us to further add criteria to the relation with
    # Rails thinking it's selecting data the usual way.
    #
    # If nested objects are not supported, ancestors_base is returned.
    # rubocop: disable CodeReuse/ActiveRecord
    def all_objects
      return ancestors_base unless hierarchy_supported?

      ancestors = base_and_ancestors_cte
      descendants = base_and_descendants_cte

      ancestors_table = ancestors.alias_to(objects_table)
      descendants_table = descendants.alias_to(objects_table)

      relation = model
        .unscoped
        .with
        .recursive(ancestors.to_arel, descendants.to_arel)
        .from_union([
          model.unscoped.from(ancestors_table),
          model.unscoped.from(descendants_table)
        ])

      read_only(relation)
    end
    # rubocop: enable CodeReuse/ActiveRecord

    private

    def hierarchy_supported?
      Gitlab::Database.postgresql?
    end

    # rubocop: disable CodeReuse/ActiveRecord
    def base_and_ancestors_cte(stop_id = nil, hierarchy_order = nil)
      cte = SQL::RecursiveCTE.new(:base_and_ancestors)
      depth_column = :depth

      base_query = ancestors_base.except(:order)
      base_query = base_query.select("1 as #{depth_column}", objects_table[Arel.star]) if hierarchy_order

      cte << base_query

      # Recursively get all the ancestors of the base set.
      parent_query = model
        .from([objects_table, cte.table])
        .where(objects_table[:id].eq(cte.table[:parent_id]))
        .except(:order)

      parent_query = parent_query.select(cte.table[depth_column] + 1, objects_table[Arel.star]) if hierarchy_order
      parent_query = parent_query.where(cte.table[:parent_id].not_eq(stop_id)) if stop_id

      cte << parent_query
      cte
    end
    # rubocop: enable CodeReuse/ActiveRecord

    # rubocop: disable CodeReuse/ActiveRecord
    def base_and_descendants_cte
      cte = SQL::RecursiveCTE.new(:base_and_descendants)

      cte << descendants_base.except(:order)

      # Recursively get all the descendants of the base set.
      cte << model
        .from([objects_table, cte.table])
        .where(objects_table[:parent_id].eq(cte.table[:id]))
        .except(:order)

      cte
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def objects_table
      model.arel_table
    end

    def read_only(relation)
      # relations using a CTE are not safe to use with update_all as it will
      # throw away the CTE, hence we mark them as read-only.
      relation.extend(Gitlab::Database::ReadOnlyRelation)
      relation
    end
  end
end
