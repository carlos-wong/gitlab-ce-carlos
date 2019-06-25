# frozen_string_literal: true

module Resolvers
  class IssuesResolver < BaseResolver
    argument :iid, GraphQL::STRING_TYPE,
              required: false,
              description: 'The IID of the issue, e.g., "1"'

    argument :iids, [GraphQL::STRING_TYPE],
              required: false,
              description: 'The list of IIDs of issues, e.g., [1, 2]'
    argument :state, Types::IssuableStateEnum,
              required: false,
              description: "Current state of Issue"
    argument :label_name, GraphQL::STRING_TYPE.to_list_type,
              required: false,
              description: "Labels applied to the Issue"
    argument :created_before, Types::TimeType,
              required: false,
              description: "Issues created before this date"
    argument :created_after, Types::TimeType,
              required: false,
              description: "Issues created after this date"
    argument :updated_before, Types::TimeType,
              required: false,
              description: "Issues updated before this date"
    argument :updated_after, Types::TimeType,
              required: false,
              description: "Issues updated after this date"
    argument :closed_before, Types::TimeType,
              required: false,
              description: "Issues closed before this date"
    argument :closed_after, Types::TimeType,
              required: false,
              description: "Issues closed after this date"
    argument :search, GraphQL::STRING_TYPE,
              required: false
    argument :sort, Types::Sort,
              required: false,
              default_value: 'created_desc'

    type Types::IssueType, null: true

    alias_method :project, :object

    def resolve(**args)
      # The project could have been loaded in batch by `BatchLoader`.
      # At this point we need the `id` of the project to query for issues, so
      # make sure it's loaded and not `nil` before continuing.
      project.sync if project.respond_to?(:sync)
      return Issue.none if project.nil?

      # Will need to be be made group & namespace aware with
      # https://gitlab.com/gitlab-org/gitlab-ce/issues/54520
      args[:project_id] = project.id
      args[:iids] ||= [args[:iid]].compact

      IssuesFinder.new(context[:current_user], args).execute
    end

    def self.resolver_complexity(args, child_complexity:)
      complexity = super
      complexity += 2 if args[:labelName]

      complexity
    end
  end
end
