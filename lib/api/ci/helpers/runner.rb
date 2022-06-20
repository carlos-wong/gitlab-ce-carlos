# frozen_string_literal: true

module API
  module Ci
    module Helpers
      module Runner
        include Gitlab::Utils::StrongMemoize

        prepend_mod_with('API::Ci::Helpers::Runner') # rubocop: disable Cop/InjectEnterpriseEditionModule

        JOB_TOKEN_HEADER = 'HTTP_JOB_TOKEN'
        JOB_TOKEN_PARAM = :token

        def authenticate_runner!
          forbidden! unless current_runner

          current_runner
            .heartbeat(get_runner_details_from_request)
        end

        def get_runner_details_from_request
          return get_runner_ip unless params['info'].present?

          attributes_for_keys(%w(name version revision platform architecture executor), params['info'])
            .merge(get_runner_config_from_request)
            .merge(get_runner_ip)
        end

        def get_runner_ip
          { ip_address: ip_address }
        end

        def current_runner
          token = params[:token]

          if token
            ::Ci::Runner.sticking.stick_or_unstick_request(env, :runner, token)
          end

          strong_memoize(:current_runner) do
            ::Ci::Runner.find_by_token(token.to_s)
          end
        end

        # HTTP status codes to terminate the job on GitLab Runner:
        # - 403
        def authenticate_job!(require_running: true, heartbeat_runner: false)
          job = current_job

          # 404 is not returned here because we want to terminate the job if it's
          # running. A 404 can be returned from anywhere in the networking stack which is why
          # we are explicit about a 403, we should improve this in
          # https://gitlab.com/gitlab-org/gitlab/-/issues/327703
          forbidden! unless job

          forbidden! unless job_token_valid?(job)

          forbidden!('Project has been deleted!') if job.project.nil? || job.project.pending_delete?
          forbidden!('Job has been erased!') if job.erased?

          if require_running
            job_forbidden!(job, 'Job is not running') unless job.running?
          end

          # Only some requests (like updating the job or patching the trace) should trigger
          # runner heartbeat. Operations like artifacts uploading are executed in context of
          # the running job and in the job environment, which in many cases will cause the IP
          # to be updated to not the expected value. And operations like artifacts downloads can
          # be done even after the job is finished and from totally different runners - while
          # they would then update the connection status of not the runner that they should.
          # Runner requests done in context of job authentication should explicitly define when
          # the heartbeat should be triggered.
          if heartbeat_runner
            job.runner&.heartbeat(get_runner_ip)
          end

          job
        end

        def current_job
          id = params[:id]

          if id
            ::Ci::Build
              .sticking
              .stick_or_unstick_request(env, :build, id)
          end

          strong_memoize(:current_job) do
            ::Ci::Build.find_by_id(id)
          end
        end

        def job_token_valid?(job)
          token = (params[JOB_TOKEN_PARAM] || env[JOB_TOKEN_HEADER]).to_s
          token && job.valid_token?(token)
        end

        def job_forbidden!(job, reason)
          header 'Job-Status', job.status
          forbidden!(reason)
        end

        def set_application_context
          return unless current_job

          Gitlab::ApplicationContext.push(job: current_job)
        end

        def track_ci_minutes_usage!(_build, _runner)
          # noop: overridden in EE
        end

        private

        def get_runner_config_from_request
          { config: attributes_for_keys(%w(gpus), params.dig('info', 'config')) }
        end
      end
    end
  end
end
