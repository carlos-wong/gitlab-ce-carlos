# frozen_string_literal: true

module Types
  module Snippets
    class BlobViewerType < BaseObject # rubocop:disable Graphql/AuthorizeTypes
      graphql_name 'SnippetBlobViewer'
      description 'Represents how the blob content should be displayed'

      field :type, Types::BlobViewers::TypeEnum,
            description: 'Type of blob viewer',
            null: false

      field :load_async, GraphQL::BOOLEAN_TYPE,
            description: 'Shows whether the blob content is loaded async',
            null: false

      field :collapsed, GraphQL::BOOLEAN_TYPE,
            description: 'Shows whether the blob should be displayed collapsed',
            method: :collapsed?,
            null: false

      field :too_large, GraphQL::BOOLEAN_TYPE,
            description: 'Shows whether the blob too large to be displayed',
            method: :too_large?,
            null: false

      field :render_error, GraphQL::STRING_TYPE,
            description: 'Error rendering the blob content',
            null: true

      field :file_type, GraphQL::STRING_TYPE,
            description: 'Content file type',
            method: :partial_name,
            null: false

      field :loading_partial_name, GraphQL::STRING_TYPE,
            description: 'Loading partial name',
            null: false
    end
  end
end
