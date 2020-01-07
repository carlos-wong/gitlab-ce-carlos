# frozen_string_literal: true

module Types
  class MilestoneType < BaseObject
    graphql_name 'Milestone'

    authorize :read_milestone

    field :id, GraphQL::ID_TYPE, null: false,
          description: 'ID of the milestone'
    field :description, GraphQL::STRING_TYPE, null: true,
          description: 'Description of the milestone'
    field :title, GraphQL::STRING_TYPE, null: false,
          description: 'Title of the milestone'
    field :state, GraphQL::STRING_TYPE, null: false,
          description: 'State of the milestone'

    field :due_date, Types::TimeType, null: true,
          description: 'Timestamp of the milestone due date'
    field :start_date, Types::TimeType, null: true,
          description: 'Timestamp of the milestone start date'

    field :created_at, Types::TimeType, null: false,
          description: 'Timestamp of milestone creation'
    field :updated_at, Types::TimeType, null: false,
          description: 'Timestamp of last milestone update'
  end
end
