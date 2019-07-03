# frozen_string_literal: true

module Types
  class LabelType < BaseObject
    graphql_name 'Label'

    authorize :read_label

    field :description, GraphQL::STRING_TYPE, null: true
    field :title, GraphQL::STRING_TYPE, null: false
    field :color, GraphQL::STRING_TYPE, null: false
    field :text_color, GraphQL::STRING_TYPE, null: false
  end
end
