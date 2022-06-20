# frozen_string_literal: true

module API
  module Ci
    class Jobs < ::API::Base
      include PaginationParams
      before { authenticate! }

      resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
        params do
          requires :id, type: String, desc: 'The ID of a project'
        end

        helpers do
          params :optional_scope do
            optional :scope, types: [String, Array[String]], desc: 'The scope of builds to show',
                             values: ::CommitStatus::AVAILABLE_STATUSES,
                             coerce_with: ->(scope) {
                               case scope
                               when String
                                 [scope]
                               when ::Hash
                                 scope.values
                               when ::Array
                                 scope
                               else
                                 ['unknown']
                               end
                             }
          end
        end

        desc 'Get a projects jobs' do
          success Entities::Ci::Job
        end
        params do
          use :optional_scope
          use :pagination
        end
        # rubocop: disable CodeReuse/ActiveRecord
        get ':id/jobs', urgency: :low, feature_category: :continuous_integration do
          authorize_read_builds!

          builds = user_project.builds.order('id DESC')
          builds = filter_builds(builds, params[:scope])

          builds = builds.preload(:user, :job_artifacts_archive, :job_artifacts, :runner, :tags, pipeline: :project)
          present paginate(builds), with: Entities::Ci::Job
        end
        # rubocop: enable CodeReuse/ActiveRecord

        desc 'Get a specific job of a project' do
          success Entities::Ci::Job
        end
        params do
          requires :job_id, type: Integer, desc: 'The ID of a job'
        end
        get ':id/jobs/:job_id', urgency: :low, feature_category: :continuous_integration do
          authorize_read_builds!

          build = find_build!(params[:job_id])

          present build, with: Entities::Ci::Job
        end

        # TODO: We should use `present_disk_file!` and leave this implementation for backward compatibility (when build trace
        #       is saved in the DB instead of file). But before that, we need to consider how to replace the value of
        #       `runners_token` with some mask (like `xxxxxx`) when sending trace file directly by workhorse.
        desc 'Get a trace of a specific job of a project'
        params do
          requires :job_id, type: Integer, desc: 'The ID of a job'
        end
        get ':id/jobs/:job_id/trace', urgency: :low, feature_category: :continuous_integration do
          authorize_read_builds!

          build = find_build!(params[:job_id])

          authorize_read_build_trace!(build) if build

          header 'Content-Disposition', "infile; filename=\"#{build.id}.log\""
          content_type 'text/plain'
          env['api.format'] = :binary

          # The trace can be nil bu body method expects a string as an argument.
          trace = build.trace.raw || ''
          body trace
        end

        desc 'Cancel a specific job of a project' do
          success Entities::Ci::Job
        end
        params do
          requires :job_id, type: Integer, desc: 'The ID of a job'
        end
        post ':id/jobs/:job_id/cancel', urgency: :low, feature_category: :continuous_integration do
          authorize_update_builds!

          build = find_build!(params[:job_id])
          authorize!(:update_build, build)

          build.cancel

          present build, with: Entities::Ci::Job
        end

        desc 'Retry a specific build of a project' do
          success Entities::Ci::Job
        end
        params do
          requires :job_id, type: Integer, desc: 'The ID of a build'
        end
        post ':id/jobs/:job_id/retry', urgency: :low, feature_category: :continuous_integration do
          authorize_update_builds!

          build = find_build!(params[:job_id])
          authorize!(:update_build, build)

          response = ::Ci::RetryJobService.new(@project, current_user).execute(build)

          if response.success?
            present response[:job], with: Entities::Ci::Job
          else
            forbidden!('Job is not retryable')
          end
        end

        desc 'Erase job (remove artifacts and the trace)' do
          success Entities::Ci::Job
        end
        params do
          requires :job_id, type: Integer, desc: 'The ID of a build'
        end
        post ':id/jobs/:job_id/erase', urgency: :low, feature_category: :continuous_integration do
          authorize_update_builds!

          build = find_build!(params[:job_id])
          authorize!(:erase_build, build)
          break forbidden!('Job is not erasable!') unless build.erasable?

          build.erase(erased_by: current_user)
          present build, with: Entities::Ci::Job
        end

        desc 'Trigger an actionable job (manual, delayed, etc)' do
          success Entities::Ci::JobBasic
          detail 'This feature was added in GitLab 8.11'
        end
        params do
          requires :job_id, type: Integer, desc: 'The ID of a Job'
          optional :job_variables_attributes, type: Array,
            desc: 'User defined variables that will be included when running the job' do
            requires :key, type: String, desc: 'The name of the variable'
            requires :value, type: String, desc: 'The value of the variable'
          end
        end

        post ':id/jobs/:job_id/play', urgency: :low, feature_category: :continuous_integration do
          authorize_read_builds!

          job = find_job!(params[:job_id])

          authorize!(:play_job, job)

          bad_request!("Unplayable Job") unless job.playable?

          job.play(current_user, params[:job_variables_attributes])

          status 200

          if job.is_a?(::Ci::Build)
            present job, with: Entities::Ci::Job
          else
            present job, with: Entities::Ci::Bridge
          end
        end
      end

      resource :job do
        desc 'Get current job using job token' do
          success Entities::Ci::Job
        end
        route_setting :authentication, job_token_allowed: true
        get '', feature_category: :continuous_integration, urgency: :low do
          validate_current_authenticated_job

          present current_authenticated_job, with: Entities::Ci::Job
        end

        desc 'Get current agents' do
          detail 'Retrieves a list of agents for the given job token'
        end
        route_setting :authentication, job_token_allowed: true
        get '/allowed_agents', feature_category: :kubernetes_management do
          validate_current_authenticated_job

          status 200

          pipeline = current_authenticated_job.pipeline
          project = current_authenticated_job.project
          agent_authorizations = ::Clusters::AgentAuthorizationsFinder.new(project).execute
          project_groups = project.group&.self_and_ancestor_ids&.map { |id| { id: id } } || []
          user_access_level = project.team.max_member_access(current_user.id)
          roles_in_project = Gitlab::Access.sym_options_with_owner
            .select { |_role, role_access_level| role_access_level <= user_access_level }
            .map(&:first)

          environment = if environment_slug = current_authenticated_job.deployment&.environment&.slug
                          { slug: environment_slug }
                        end

          # See https://gitlab.com/gitlab-org/cluster-integration/gitlab-agent/-/blob/master/doc/kubernetes_ci_access.md#apiv4joballowed_agents-api
          {
            allowed_agents: Entities::Clusters::AgentAuthorization.represent(agent_authorizations),
            job: { id: current_authenticated_job.id },
            pipeline: { id: pipeline.id },
            project: { id: project.id, groups: project_groups },
            user: { id: current_user.id, username: current_user.username, roles_in_project: roles_in_project },
            environment: environment
          }.compact
        end
      end

      helpers do
        # rubocop: disable CodeReuse/ActiveRecord
        def filter_builds(builds, scope)
          return builds if scope.nil? || scope.empty?

          available_statuses = ::CommitStatus::AVAILABLE_STATUSES

          unknown = scope - available_statuses
          render_api_error!('Scope contains invalid value(s)', 400) unless unknown.empty?

          builds.where(status: available_statuses && scope)
        end
        # rubocop: enable CodeReuse/ActiveRecord

        def validate_current_authenticated_job
          # current_authenticated_job will be nil if user is using
          # a valid authentication (like PRIVATE-TOKEN) that is not CI_JOB_TOKEN
          not_found!('Job') unless current_authenticated_job
        end
      end
    end
  end
end
