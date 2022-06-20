# frozen_string_literal: true

# rubocop: disable CodeReuse/ActiveRecord
class EventFilter
  include Gitlab::Utils::StrongMemoize

  attr_accessor :filter

  ALL = 'all'
  PUSH = 'push'
  MERGED = 'merged'
  ISSUE = 'issue'
  COMMENTS = 'comments'
  TEAM = 'team'
  WIKI = 'wiki'
  DESIGNS = 'designs'

  def initialize(filter)
    # Split using comma to maintain backward compatibility Ex/ "filter1,filter2"
    filter = filter.to_s.split(',')[0].to_s
    @filter = filters.include?(filter) ? filter : ALL
  end

  def active?(key)
    filter == key.to_s
  end

  def apply_filter(events)
    case filter
    when PUSH
      events.pushed_action
    when MERGED
      events.merged_action
    when COMMENTS
      events.commented_action
    when TEAM
      events.where(action: Event::TEAM_ACTIONS)
    when ISSUE
      events.where(action: Event::ISSUE_ACTIONS, target_type: 'Issue')
    when WIKI
      wiki_events(events)
    when DESIGNS
      design_events(events)
    else
      events
    end
  end

  # rubocop: disable Metrics/CyclomaticComplexity
  # This method build specialized in-operator optimized queries based on different
  # filter parameters. All queries will benefit from the index covering the following columns:
  # author_id target_type action id
  #
  # More context: https://docs.gitlab.com/ee/development/database/efficient_in_operator_queries.html#the-inoperatoroptimization-module
  def in_operator_query_builder_params(user_ids)
    case filter
    when ALL
      in_operator_params(array_scope_ids: user_ids)
    when PUSH
      # Here we need to add an order hint column to force the correct index usage.
      # Without the order hint, the following conditions will use the `index_events_on_author_id_and_id`
      # index which is not as efficient as the `index_events_for_followed_users` index.
      # > target_type IS NULL AND action = 5 AND author_id = X ORDER BY id DESC
      #
      # The order hint adds an extra order by column which doesn't affect the result but forces the planner
      # to use the correct index:
      # > target_type IS NULL AND action = 5 AND author_id = X ORDER BY target_type DESC, id DESC
      in_operator_params(
        array_scope_ids: user_ids,
        scope: Event.where(target_type: nil).pushed_action,
        order_hint_column: :target_type
      )
    when MERGED
      in_operator_params(
        array_scope_ids: user_ids,
        scope: Event.where(target_type: MergeRequest.to_s).merged_action
      )
    when COMMENTS
      in_operator_params(
        array_scope_ids: user_ids,
        scope: Event.commented_action,
        in_column: :target_type,
        in_values: [Note, *Note.descendants].map(&:name) # To make the query efficient we need to list all Note classes
      )
    when TEAM
      in_operator_params(
        array_scope_ids: user_ids,
        scope: Event.where(target_type: nil),
        order_hint_column: :target_type,
        in_column: :action,
        in_values: Event.actions.values_at(*Event::TEAM_ACTIONS)
      )
    when ISSUE
      in_operator_params(
        array_scope_ids: user_ids,
        scope: Event.where(target_type: Issue.name),
        in_column: :action,
        in_values: Event.actions.values_at(*Event::ISSUE_ACTIONS)
      )
    when WIKI
      in_operator_params(
        array_scope_ids: user_ids,
        scope: Event.for_wiki_page,
        in_column: :action,
        in_values: Event.actions.values_at(*Event::WIKI_ACTIONS)
      )
    when DESIGNS
      in_operator_params(
        array_scope_ids: user_ids,
        scope: Event.for_design,
        in_column: :action,
        in_values: Event.actions.values_at(*Event::DESIGN_ACTIONS)
      )
    else
      in_operator_params(array_scope_ids: user_ids)
    end
  end
  # rubocop: enable Metrics/CyclomaticComplexity

  private

  def in_operator_params(array_scope_ids:, scope: nil, in_column: nil, in_values: nil, order_hint_column: nil)
    base_scope = Event.all
    base_scope = base_scope.merge(scope) if scope

    order = { id: :desc }
    finder_query = -> (id_expression) { Event.where(Event.arel_table[:id].eq(id_expression)) }

    if order_hint_column.present?
      order = Gitlab::Pagination::Keyset::Order.build([
        Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
          attribute_name: order_hint_column,
          order_expression: Event.arel_table[order_hint_column].desc,
          nullable: :nulls_last,
          distinct: false
        ),
        Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
          attribute_name: :id,
          order_expression: Event.arel_table[:id].desc
        )
      ])

      finder_query = -> (_order_hint, id_expression) { Event.where(Event.arel_table[:id].eq(id_expression)) }
    end

    base_scope = base_scope.reorder(order)

    array_params = in_operator_array_params(
      array_scope_ids: array_scope_ids,
      scope: base_scope,
      in_column: in_column,
      in_values: in_values
    )

    array_params.merge(
      scope: base_scope,
      finder_query: finder_query
    )
  end

  # This method builds the array_ parameters
  # without in_column parameter: uses one IN filter: author_id
  # with in_column: two IN filters: author_id, (target_type OR action)
  def in_operator_array_params(scope:, array_scope_ids:, in_column: nil, in_values: nil)
    if in_column
      # Builds Carthesian product of the in_values and the array_scope_ids (in this case: user_ids).
      # The process is described here: https://docs.gitlab.com/ee/development/database/efficient_in_operator_queries.html#multiple-in-queries
      # VALUES ((array_scope_ids[0], in_values[0]), (array_scope_ids[1], in_values[0]) ...)
      cartesian = array_scope_ids.product(in_values)
      user_with_column_list = Arel::Nodes::ValuesList.new(cartesian)

      as = "array_ids(id, #{Event.connection.quote_column_name(in_column)})"
      from = Arel::Nodes::Grouping.new(user_with_column_list).as(as)
      {
        array_scope: User.select(:id, in_column).from(from),
        array_mapping_scope: -> (author_id_expression, in_column_expression) do
          Event
            .merge(scope)
            .where(Event.arel_table[:author_id].eq(author_id_expression))
            .where(Event.arel_table[in_column].eq(in_column_expression))
        end
      }
    else
      # Builds a simple query to represent the array_scope_ids
      # VALUES ((array_scope_ids[0]), (array_scope_ids[2])...)
      array_ids_list = Arel::Nodes::ValuesList.new(array_scope_ids.map { |id| [id] })
      from = Arel::Nodes::Grouping.new(array_ids_list).as('array_ids(id)')
      {
        array_scope: User.select(:id).from(from),
        array_mapping_scope: -> (author_id_expression) do
          Event
            .merge(scope)
            .where(Event.arel_table[:author_id].eq(author_id_expression))
        end
      }
    end
  end

  def wiki_events(events)
    events.for_wiki_page
  end

  def design_events(events)
    events.for_design
  end

  def filters
    [ALL, PUSH, MERGED, ISSUE, COMMENTS, TEAM, WIKI, DESIGNS]
  end
end
# rubocop: enable CodeReuse/ActiveRecord

EventFilter.prepend_mod_with('EventFilter')
