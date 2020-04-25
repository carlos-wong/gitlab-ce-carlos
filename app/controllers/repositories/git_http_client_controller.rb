# frozen_string_literal: true

module Repositories
  class GitHttpClientController < Repositories::ApplicationController
    include ActionController::HttpAuthentication::Basic
    include KerberosSpnegoHelper
    include Gitlab::Utils::StrongMemoize

    attr_reader :authentication_result, :redirected_path

    delegate :actor, :authentication_abilities, to: :authentication_result, allow_nil: true
    delegate :type, to: :authentication_result, allow_nil: true, prefix: :auth_result

    alias_method :user, :actor
    alias_method :authenticated_user, :actor

    # Git clients will not know what authenticity token to send along
    skip_around_action :set_session_storage
    skip_before_action :verify_authenticity_token

    before_action :parse_repo_path
    before_action :authenticate_user

    private

    def download_request?
      raise NotImplementedError
    end

    def upload_request?
      raise NotImplementedError
    end

    def authenticate_user
      @authentication_result = Gitlab::Auth::Result.new

      if allow_basic_auth? && basic_auth_provided?
        login, password = user_name_and_password(request)

        if handle_basic_authentication(login, password)
          return # Allow access
        end
      elsif allow_kerberos_spnego_auth? && spnego_provided?
        kerberos_user = find_kerberos_user

        if kerberos_user
          @authentication_result = Gitlab::Auth::Result.new(
            kerberos_user, nil, :kerberos, Gitlab::Auth.full_authentication_abilities)

          send_final_spnego_response
          return # Allow access
        end
      elsif http_download_allowed?

        @authentication_result = Gitlab::Auth::Result.new(nil, project, :none, [:download_code])

        return # Allow access
      end

      send_challenges
      render plain: "HTTP Basic: Access denied\n", status: :unauthorized
    rescue Gitlab::Auth::MissingPersonalAccessTokenError
      render_missing_personal_access_token
    end

    def basic_auth_provided?
      has_basic_credentials?(request)
    end

    def send_challenges
      challenges = []
      challenges << 'Basic realm="GitLab"' if allow_basic_auth?
      challenges << spnego_challenge if allow_kerberos_spnego_auth?
      headers['Www-Authenticate'] = challenges.join("\n") if challenges.any?
    end

    def project
      parse_repo_path unless defined?(@project)

      @project
    end

    def parse_repo_path
      @project, @repo_type, @redirected_path = Gitlab::RepoPath.parse("#{params[:namespace_id]}/#{params[:repository_id]}")
    end

    def render_missing_personal_access_token
      render plain: "HTTP Basic: Access denied\n" \
                    "You must use a personal access token with 'read_repository' or 'write_repository' scope for Git over HTTP.\n" \
                    "You can generate one at #{profile_personal_access_tokens_url}",
            status: :unauthorized
    end

    def repository
      strong_memoize(:repository) do
        repo_type.repository_for(project)
      end
    end

    def repo_type
      parse_repo_path unless defined?(@repo_type)

      @repo_type
    end

    def handle_basic_authentication(login, password)
      @authentication_result = Gitlab::Auth.find_for_git_client(
        login, password, project: project, ip: request.ip)

      @authentication_result.success?
    end

    def ci?
      authentication_result.ci?(project)
    end

    def http_download_allowed?
      Gitlab::ProtocolAccess.allowed?('http') &&
      download_request? &&
      project && Guest.can?(:download_code, project)
    end
  end
end

Repositories::GitHttpClientController.prepend_if_ee('EE::Repositories::GitHttpClientController')
