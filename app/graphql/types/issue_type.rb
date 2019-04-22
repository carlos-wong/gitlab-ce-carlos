# frozen_string_literal: true

module Types
  class IssueType < BaseObject
    graphql_name 'Issue'

    authorize :read_issue

    expose_permissions Types::PermissionTypes::Issue

    present_using IssuePresenter

    field :iid, GraphQL::ID_TYPE, null: false
    field :title, GraphQL::STRING_TYPE, null: false
    field :description, GraphQL::STRING_TYPE, null: true
    field :state, IssueStateEnum, null: false

    field :author, Types::UserType,
          null: false,
          resolve: -> (obj, _args, _ctx) { Gitlab::Graphql::Loaders::BatchModelLoader.new(User, obj.author_id).find }

    field :assignees, Types::UserType.connection_type, null: true

    field :labels, Types::LabelType.connection_type, null: true
    field :milestone, Types::MilestoneType,
          null: true,
          resolve: -> (obj, _args, _ctx) { Gitlab::Graphql::Loaders::BatchModelLoader.new(Milestone, obj.milestone_id).find }

    field :due_date, Types::TimeType, null: true
    field :confidential, GraphQL::BOOLEAN_TYPE, null: false
    field :discussion_locked, GraphQL::BOOLEAN_TYPE,
          null: false,
          resolve: -> (obj, _args, _ctx) { !!obj.discussion_locked }

    field :upvotes, GraphQL::INT_TYPE, null: false
    field :downvotes, GraphQL::INT_TYPE, null: false
    field :user_notes_count, GraphQL::INT_TYPE, null: false
    field :web_url, GraphQL::STRING_TYPE, null: false

    field :closed_at, Types::TimeType, null: true

    field :created_at, Types::TimeType, null: false
    field :updated_at, Types::TimeType, null: false
  end
end
