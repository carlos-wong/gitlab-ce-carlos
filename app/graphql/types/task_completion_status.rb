# frozen_string_literal: true

module Types
  # rubocop: disable Graphql/AuthorizeTypes
  # This is used in `IssueType` and `MergeRequestType` both of which have their
  # own authorization
  class TaskCompletionStatus < BaseObject
    graphql_name 'TaskCompletionStatus'
    description 'Completion status of tasks'

    field :count, GraphQL::INT_TYPE, null: false # rubocop:disable Graphql/Descriptions
    field :completed_count, GraphQL::INT_TYPE, null: false # rubocop:disable Graphql/Descriptions
  end
  # rubocop: enable Graphql/AuthorizeTypes
end
