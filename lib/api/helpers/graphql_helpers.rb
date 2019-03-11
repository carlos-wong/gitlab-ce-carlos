# frozen_string_literal: true

module API
  module Helpers
    # GraphqlHelpers is used by the REST API when it is acting like a client
    # against the graphql API. Helper code for the graphql server implementation
    # should be in app/graphql/ or lib/gitlab/graphql/
    module GraphqlHelpers
      def conditionally_graphql!(fallback:, query:, context: {}, transform: nil)
        return fallback.call unless Feature.enabled?(:graphql)

        result = GitlabSchema.execute(query, context: context)

        if transform
          transform.call(result)
        else
          result
        end
      end
    end
  end
end
