# frozen_string_literal: true

module Mutations
  class BaseMutation < GraphQL::Schema::RelayClassicMutation
    prepend Gitlab::Graphql::Authorize::AuthorizeResource
    prepend Gitlab::Graphql::CopyFieldDescription

    ERROR_MESSAGE = 'You cannot perform write operations on a read-only instance'

    field :errors, [GraphQL::STRING_TYPE],
          null: false,
          description: "Reasons why the mutation failed."

    def current_user
      context[:current_user]
    end

    # Returns Array of errors on an ActiveRecord object
    def errors_on_object(record)
      record.errors.full_messages
    end

    def ready?(**args)
      if Gitlab::Database.read_only?
        raise Gitlab::Graphql::Errors::ResourceNotAvailable, ERROR_MESSAGE
      else
        true
      end
    end
  end
end
