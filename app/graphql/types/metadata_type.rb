# frozen_string_literal: true

module Types
  class MetadataType < ::Types::BaseObject
    graphql_name 'Metadata'

    authorize :read_instance_metadata

    field :version, GraphQL::STRING_TYPE, null: false,
          description: 'Version'
    field :revision, GraphQL::STRING_TYPE, null: false,
          description: 'Revision'
  end
end
