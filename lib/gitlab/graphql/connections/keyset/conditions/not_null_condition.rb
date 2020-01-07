# frozen_string_literal: true

module Gitlab
  module Graphql
    module Connections
      module Keyset
        module Conditions
          class NotNullCondition < BaseCondition
            def build
              conditions = [first_attribute_condition]

              # If there is only one order field, we can assume it
              # does not contain NULLs, and don't need additional
              # conditions
              unless names.count == 1
                conditions << [second_attribute_condition, final_condition]
              end

              conditions.join
            end

            private

            # ex: "(relative_position > 23)"
            def first_attribute_condition
              <<~SQL
                (#{table_condition(names.first, values.first, operator.first).to_sql})
              SQL
            end

            # ex: " OR (relative_position = 23 AND id > 500)"
            def second_attribute_condition
              condition = <<~SQL
                OR (
                  #{table_condition(names.first, values.first, '=').to_sql}
                  AND
                  #{table_condition(names[1], values[1], operator[1]).to_sql}
                )
              SQL

              condition
            end

            # ex: " OR (relative_position IS NULL)"
            def final_condition
              if before_or_after == :after
                <<~SQL
                  OR (#{table_condition(names.first, nil, 'is_null').to_sql})
                SQL
              end
            end
          end
        end
      end
    end
  end
end
