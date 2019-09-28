# frozen_string_literal: true

module Types
  class LabelType < BaseObject
    graphql_name 'Label'

    authorize :read_label

    field :description, GraphQL::STRING_TYPE, null: true # rubocop:disable Graphql/Descriptions
    markdown_field :description_html, null: true
    field :title, GraphQL::STRING_TYPE, null: false # rubocop:disable Graphql/Descriptions
    field :color, GraphQL::STRING_TYPE, null: false # rubocop:disable Graphql/Descriptions
    field :text_color, GraphQL::STRING_TYPE, null: false # rubocop:disable Graphql/Descriptions
  end
end
