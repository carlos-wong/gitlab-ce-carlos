# frozen_string_literal: true

module Types
  module Notes
    class NoteType < BaseObject
      graphql_name 'Note'

      authorize :read_note

      expose_permissions Types::PermissionTypes::Note

      field :id, GraphQL::ID_TYPE, null: false # rubocop:disable Graphql/Descriptions

      field :project, Types::ProjectType,
            null: true,
            description: "The project this note is associated to",
            resolve: -> (note, args, context) { Gitlab::Graphql::Loaders::BatchModelLoader.new(Project, note.project_id).find }

      field :author, Types::UserType,
            null: false,
            description: "The user who wrote this note",
            resolve: -> (note, args, context) { Gitlab::Graphql::Loaders::BatchModelLoader.new(User, note.author_id).find }

      field :resolved_by, Types::UserType,
            null: true,
            description: "The user that resolved the discussion",
            resolve: -> (note, _args, _context) { Gitlab::Graphql::Loaders::BatchModelLoader.new(User, note.resolved_by_id).find }

      field :system, GraphQL::BOOLEAN_TYPE,
            null: false,
            description: "Whether or not this note was created by the system or by a user"

      field :body, GraphQL::STRING_TYPE,
            null: false,
            method: :note,
            description: "The content note itself"

      markdown_field :body_html, null: true, method: :note

      field :created_at, Types::TimeType, null: false # rubocop:disable Graphql/Descriptions
      field :updated_at, Types::TimeType, null: false # rubocop:disable Graphql/Descriptions
      field :discussion, Types::Notes::DiscussionType, null: true, description: "The discussion this note is a part of"
      field :resolvable, GraphQL::BOOLEAN_TYPE, null: false, method: :resolvable? # rubocop:disable Graphql/Descriptions
      field :resolved_at, Types::TimeType, null: true, description: "The time the discussion was resolved"
      field :position, Types::Notes::DiffPositionType, null: true, description: "The position of this note on a diff"
    end
  end
end
