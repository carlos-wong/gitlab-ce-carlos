# frozen_string_literal: true

module Gitlab
  class GitAccessWiki < GitAccess
    extend ::Gitlab::Utils::Override

    ERROR_MESSAGES = {
      download: 'You are not allowed to download files from this wiki.',
      not_found: 'The wiki you were looking for could not be found.',
      no_repo: 'A repository for this wiki does not exist yet.',
      read_only: "You can't push code to a read-only GitLab instance.",
      write_to_wiki: "You are not allowed to write to this project's wiki."
    }.freeze

    override :project
    def project
      container.project if container.is_a?(ProjectWiki)
    end

    override :download_ability
    def download_ability
      :download_wiki_code
    end

    override :push_ability
    def push_ability
      :create_wiki
    end

    override :check_download_access!
    def check_download_access!
      super

      raise ForbiddenError, download_forbidden_message if build_cannot_download?
      raise ForbiddenError, download_forbidden_message if deploy_token_cannot_download?
    end

    override :check_change_access!
    def check_change_access!
      raise ForbiddenError, write_to_wiki_message unless user_can_push?

      true
    end

    def push_to_read_only_message
      error_message(:read_only)
    end

    def write_to_wiki_message
      error_message(:write_to_wiki)
    end

    def not_found_message
      error_message(:not_found)
    end

    private

    # when accessing via the CI_JOB_TOKEN
    def build_cannot_download?
      build_can_download_code? && !user_access.can_do_action?(download_ability)
    end

    def deploy_token_cannot_download?
      deploy_token && !deploy_token.can?(download_ability, container)
    end
  end
end

Gitlab::GitAccessWiki.prepend_mod_with('Gitlab::GitAccessWiki')
