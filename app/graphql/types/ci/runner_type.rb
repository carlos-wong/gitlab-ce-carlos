# frozen_string_literal: true

module Types
  module Ci
    class RunnerType < BaseObject
      graphql_name 'CiRunner'

      edge_type_class(RunnerWebUrlEdge)
      connection_type_class(Types::CountableConnectionType)

      authorize :read_runner
      present_using ::Ci::RunnerPresenter
      expose_permissions Types::PermissionTypes::Ci::Runner

      JOB_COUNT_LIMIT = 1000

      alias_method :runner, :object

      field :access_level, ::Types::Ci::RunnerAccessLevelEnum, null: false,
            description: 'Access level of the runner.'
      field :active, GraphQL::Types::Boolean, null: false,
            description: 'Indicates the runner is allowed to receive jobs.',
            deprecated: { reason: 'Use paused', milestone: '14.8' }
      field :admin_url, GraphQL::Types::String, null: true,
            description: 'Admin URL of the runner. Only available for administrators.'
      field :contacted_at, Types::TimeType, null: true,
            description: 'Timestamp of last contact from this runner.',
            method: :contacted_at
      field :created_at, Types::TimeType, null: true,
            description: 'Timestamp of creation of this runner.'
      field :description, GraphQL::Types::String, null: true,
            description: 'Description of the runner.'
      field :edit_admin_url, GraphQL::Types::String, null: true,
            description: 'Admin form URL of the runner. Only available for administrators.'
      field :executor_name, GraphQL::Types::String, null: true,
            description: 'Executor last advertised by the runner.',
            method: :executor_name
      field :platform_name, GraphQL::Types::String, null: true,
            description: 'Platform provided by the runner.',
            method: :platform
      field :architecture_name, GraphQL::Types::String, null: true,
            description: 'Architecture provided by the the runner.',
            method: :architecture
      field :maintenance_note, GraphQL::Types::String, null: true,
            description: 'Runner\'s maintenance notes.'
      field :groups, ::Types::GroupType.connection_type, null: true,
            description: 'Groups the runner is associated with. For group runners only.'
      field :id, ::Types::GlobalIDType[::Ci::Runner], null: false,
            description: 'ID of the runner.'
      field :ip_address, GraphQL::Types::String, null: true,
            description: 'IP address of the runner.'
      field :job_count, GraphQL::Types::Int, null: true,
            description: "Number of jobs processed by the runner (limited to #{JOB_COUNT_LIMIT}, plus one to indicate that more items exist)."
      field :jobs, ::Types::Ci::JobType.connection_type, null: true,
            description: 'Jobs assigned to the runner.',
            authorize: :read_builds,
            resolver: ::Resolvers::Ci::RunnerJobsResolver
      field :locked, GraphQL::Types::Boolean, null: true,
            description: 'Indicates the runner is locked.'
      field :maximum_timeout, GraphQL::Types::Int, null: true,
            description: 'Maximum timeout (in seconds) for jobs processed by the runner.'
      field :paused, GraphQL::Types::Boolean, null: false,
            description: 'Indicates the runner is paused and not available to run jobs.'
      field :project_count, GraphQL::Types::Int, null: true,
            description: 'Number of projects that the runner is associated with.'
      field :projects, ::Types::ProjectType.connection_type, null: true,
            description: 'Projects the runner is associated with. For project runners only.'
      field :revision, GraphQL::Types::String, null: true,
            description: 'Revision of the runner.'
      field :run_untagged, GraphQL::Types::Boolean, null: false,
            description: 'Indicates the runner is able to run untagged jobs.'
      field :runner_type, ::Types::Ci::RunnerTypeEnum, null: false,
            description: 'Type of the runner.'
      field :short_sha, GraphQL::Types::String, null: true,
            description: %q(First eight characters of the runner's token used to authenticate new job requests. Used as the runner's unique ID.)
      field :status,
            Types::Ci::RunnerStatusEnum,
            null: false,
            description: 'Status of the runner.',
            resolver: ::Resolvers::Ci::RunnerStatusResolver # TODO: Remove :resolver in %17.0
      field :tag_list, [GraphQL::Types::String], null: true,
            description: 'Tags associated with the runner.'
      field :token_expires_at, Types::TimeType, null: true,
            description: 'Runner token expiration time.',
            method: :token_expires_at
      field :version, GraphQL::Types::String, null: true,
            description: 'Version of the runner.'
      field :owner_project, ::Types::ProjectType, null: true,
            description: 'Project that owns the runner. For project runners only.',
            resolver: ::Resolvers::Ci::RunnerOwnerProjectResolver

      markdown_field :maintenance_note_html, null: true

      def maintenance_note_html_resolver
        ::MarkupHelper.markdown(object.maintenance_note, context.to_h.dup)
      end

      def job_count
        # We limit to 1 above the JOB_COUNT_LIMIT to indicate that more items exist after JOB_COUNT_LIMIT
        runner.builds.limit(JOB_COUNT_LIMIT + 1).count
      end

      def admin_url
        Gitlab::Routing.url_helpers.admin_runner_url(runner) if can_admin_runners?
      end

      def edit_admin_url
        Gitlab::Routing.url_helpers.edit_admin_runner_url(runner) if can_admin_runners?
      end

      # rubocop: disable CodeReuse/ActiveRecord
      def project_count
        BatchLoader::GraphQL.for(runner.id).batch(key: :runner_project_count) do |ids, loader, args|
          counts = ::Ci::Runner.project_type
            .select(:id, 'COUNT(ci_runner_projects.id) as count')
            .left_outer_joins(:runner_projects)
            .where(id: ids)
            .group(:id)
            .index_by(&:id)

          ids.each do |id|
            loader.call(id, counts[id]&.count)
          end
        end
      end
      # rubocop: enable CodeReuse/ActiveRecord

      def groups
        return unless runner.group_type?

        batched_owners(::Ci::RunnerNamespace, Group, :runner_groups, :namespace_id)
      end

      def projects
        return unless runner.project_type?

        batched_owners(::Ci::RunnerProject, Project, :runner_projects, :project_id)
      end

      private

      def can_admin_runners?
        context[:current_user]&.can_admin_all_resources?
      end

      # rubocop: disable CodeReuse/ActiveRecord
      def batched_owners(runner_assoc_type, assoc_type, key, column_name)
        BatchLoader::GraphQL.for(runner.id).batch(key: key) do |runner_ids, loader|
          plucked_runner_and_owner_ids = runner_assoc_type
            .select(:runner_id, column_name)
            .where(runner_id: runner_ids)
            .pluck(:runner_id, column_name)
          # In plucked_runner_and_owner_ids, first() represents the runner ID, and second() the owner ID,
          # so let's group the owner IDs by runner ID
          runner_owner_ids_by_runner_id = plucked_runner_and_owner_ids
            .group_by(&:first)
            .transform_values { |runner_and_owner_id| runner_and_owner_id.map(&:second) }

          owner_ids = runner_owner_ids_by_runner_id.values.flatten.uniq
          owners = assoc_type.where(id: owner_ids).index_by(&:id)

          # Preload projects namespaces to avoid N+1 queries when checking the `read_project` policy for each
          preload_projects_namespaces(owners.values) if assoc_type == Project

          runner_ids.each do |runner_id|
            loader.call(runner_id, runner_owner_ids_by_runner_id[runner_id]&.map { |owner_id| owners[owner_id] } || [])
          end
        end
      end
      # rubocop: enable CodeReuse/ActiveRecord

      def preload_projects_namespaces(_projects)
        # overridden in EE
      end
    end
  end
end

Types::Ci::RunnerType.prepend_mod_with('Types::Ci::RunnerType')
