# frozen_string_literal: true

module FromUnion
  extend ActiveSupport::Concern

  class_methods do
    # Produces a query that uses a FROM to select data using a UNION.
    #
    # Using a FROM for a UNION has in the past lead to better query plans. As
    # such, we generally recommend this pattern instead of using a WHERE IN.
    #
    # Example:
    #     users = User.from_union([User.where(id: 1), User.where(id: 2)])
    #
    # This would produce the following SQL query:
    #
    #     SELECT *
    #     FROM (
    #       SELECT *
    #       FROM users
    #       WHERE id = 1
    #
    #       UNION
    #
    #       SELECT *
    #       FROM users
    #       WHERE id = 2
    #     ) users;
    #
    # members - An Array of ActiveRecord::Relation objects to use in the UNION.
    #
    # remove_duplicates - A boolean indicating if duplicate entries should be
    #                     removed. Defaults to true.
    #
    # alias_as - The alias to use for the sub query. Defaults to the name of the
    #            table of the current model.
    # rubocop: disable Gitlab/Union
    def from_union(members, remove_duplicates: true, alias_as: table_name)
      union = Gitlab::SQL::Union
        .new(members, remove_duplicates: remove_duplicates)
        .to_sql

      from(Arel.sql("(#{union}) #{alias_as}"))
    end
    # rubocop: enable Gitlab/Union
  end
end
