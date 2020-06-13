# frozen_string_literal: true

module Mutations
  module Issues
    class Base < BaseMutation
      include Mutations::ResolvesIssuable

      argument :project_path, GraphQL::ID_TYPE,
               required: true,
               description: "The project the issue to mutate is in"

      argument :iid, GraphQL::STRING_TYPE,
               required: true,
               description: "The iid of the issue to mutate"

      field :issue,
            Types::IssueType,
            null: true,
            description: "The issue after mutation"

      authorize :update_issue

      private

      def find_object(project_path:, iid:)
        resolve_issuable(type: :issue, parent_path: project_path, iid: iid)
      end
    end
  end
end
