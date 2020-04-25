# frozen_string_literal: true

module API
  module Helpers
    module InternalHelpers
      attr_reader :redirected_path

      delegate :wiki?, to: :repo_type

      def actor
        @actor ||= Support::GitAccessActor.from_params(params)
      end

      def repo_type
        set_project unless defined?(@repo_type) # rubocop:disable Gitlab/ModuleWithInstanceVariables
        @repo_type # rubocop:disable Gitlab/ModuleWithInstanceVariables
      end

      def project
        set_project unless defined?(@project) # rubocop:disable Gitlab/ModuleWithInstanceVariables
        @project # rubocop:disable Gitlab/ModuleWithInstanceVariables
      end

      def access_checker_for(actor, protocol)
        access_checker_klass.new(actor.key_or_user, project, protocol,
          authentication_abilities: ssh_authentication_abilities,
          namespace_path: namespace_path,
          project_path: project_path,
          redirected_path: redirected_path)
      end

      def access_checker_klass
        repo_type.access_checker_class
      end

      def ssh_authentication_abilities
        [
          :read_project,
          :download_code,
          :push_code
        ]
      end

      def parse_env
        return {} if params[:env].blank?

        JSON.parse(params[:env])
      rescue JSON::ParserError
        {}
      end

      def log_user_activity(actor)
        commands = Gitlab::GitAccess::DOWNLOAD_COMMANDS

        ::Users::ActivityService.new(actor).execute if commands.include?(params[:action])
      end

      def redis_ping
        result = Gitlab::Redis::SharedState.with { |redis| redis.ping }

        result == 'PONG'
      rescue => e
        Rails.logger.warn("GitLab: An unexpected error occurred in pinging to Redis: #{e}") # rubocop:disable Gitlab/RailsLogger
        false
      end

      def project_path
        project&.path || project_path_match[:project_path]
      end

      def namespace_path
        project&.namespace&.full_path || project_path_match[:namespace_path]
      end

      private

      def project_path_match
        @project_path_match ||= params[:project].match(Gitlab::PathRegex.full_project_git_path_regex) || {}
      end

      # rubocop:disable Gitlab/ModuleWithInstanceVariables
      def set_project
        @project, @repo_type, @redirected_path =
          if params[:gl_repository]
            Gitlab::GlRepository.parse(params[:gl_repository])
          elsif params[:project]
            Gitlab::RepoPath.parse(params[:project])
          end
      end
      # rubocop:enable Gitlab/ModuleWithInstanceVariables

      # Project id to pass between components that don't share/don't have
      # access to the same filesystem mounts
      def gl_repository
        repo_type.identifier_for_container(project)
      end

      def gl_project_path
        repository.full_path
      end

      # Return the repository depending on whether we want the wiki or the
      # regular repository
      def repository
        @repository ||= repo_type.repository_for(project)
      end

      # Return the Gitaly Address if it is enabled
      def gitaly_payload(action)
        return unless %w[git-receive-pack git-upload-pack git-upload-archive].include?(action)

        {
          repository: repository.gitaly_repository,
          address: Gitlab::GitalyClient.address(project.repository_storage),
          token: Gitlab::GitalyClient.token(project.repository_storage),
          features: Feature::Gitaly.server_feature_flags
        }
      end
    end
  end
end
