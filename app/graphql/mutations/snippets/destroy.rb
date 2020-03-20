# frozen_string_literal: true

module Mutations
  module Snippets
    class Destroy < Base
      graphql_name 'DestroySnippet'

      ERROR_MSG = 'Error deleting the snippet'

      argument :id,
               GraphQL::ID_TYPE,
               required: true,
               description: 'The global id of the snippet to destroy'

      def resolve(id:)
        snippet = authorized_find!(id: id)

        response = ::Snippets::DestroyService.new(current_user, snippet).execute
        errors = response.success? ? [] : [ERROR_MSG]

        {
          errors: errors
        }
      end

      private

      def ability_name
        "admin"
      end
    end
  end
end
