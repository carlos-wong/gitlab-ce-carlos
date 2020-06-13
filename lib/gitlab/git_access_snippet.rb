# frozen_string_literal: true

module Gitlab
  class GitAccessSnippet < GitAccess
    extend ::Gitlab::Utils::Override

    ERROR_MESSAGES = {
      authentication_mechanism: 'The authentication mechanism is not supported.',
      read_snippet: 'You are not allowed to read this snippet.',
      update_snippet: 'You are not allowed to update this snippet.',
      snippet_not_found: 'The snippet you were looking for could not be found.',
      repository_not_found: 'The snippet repository you were looking for could not be found.'
    }.freeze

    attr_reader :snippet

    def initialize(actor, snippet, protocol, **kwargs)
      @snippet = snippet

      super(actor, snippet&.project, protocol, **kwargs)

      @auth_result_type = nil
      @authentication_abilities &= [:download_code, :push_code]
    end

    def check(cmd, changes)
      # TODO: Investigate if expanding actor/authentication types are needed.
      # https://gitlab.com/gitlab-org/gitlab/issues/202190
      if actor && !actor.is_a?(User) && !actor.instance_of?(Key)
        raise ForbiddenError, ERROR_MESSAGES[:authentication_mechanism]
      end

      check_snippet_accessibility!

      super
    end

    private

    override :check_project!
    def check_project!(cmd, changes)
      return unless snippet.is_a?(ProjectSnippet)

      check_namespace!
      check_project_accessibility!
      add_project_moved_message!
    end

    override :check_push_access!
    def check_push_access!
      raise ForbiddenError, ERROR_MESSAGES[:update_snippet] unless user

      check_change_access!
    end

    override :repository
    def repository
      snippet&.repository
    end

    def check_snippet_accessibility!
      if snippet.blank?
        raise NotFoundError, ERROR_MESSAGES[:snippet_not_found]
      end
    end

    override :check_download_access!
    def check_download_access!
      passed = guest_can_download_code? || user_can_download_code?

      unless passed
        raise ForbiddenError, ERROR_MESSAGES[:read_snippet]
      end
    end

    override :guest_can_download_code?
    def guest_can_download_code?
      Guest.can?(:read_snippet, snippet)
    end

    override :user_can_download_code?
    def user_can_download_code?
      authentication_abilities.include?(:download_code) && user_access.can_do_action?(:read_snippet)
    end

    override :check_change_access!
    def check_change_access!
      unless user_access.can_do_action?(:update_snippet)
        raise ForbiddenError, ERROR_MESSAGES[:update_snippet]
      end

      changes_list.each do |change|
        # If user does not have access to make at least one change, cancel all
        # push by allowing the exception to bubble up
        check_single_change_access(change)
      end
    end

    def check_single_change_access(change)
      Checks::SnippetCheck.new(change, logger: logger).validate!
      Checks::PushFileCountCheck.new(change, repository: repository, limit: Snippet::MAX_FILE_COUNT, logger: logger).validate!
    rescue Checks::TimedLogger::TimeoutError
      raise TimeoutError, logger.full_message
    end

    override :check_repository_existence!
    def check_repository_existence!
      unless repository.exists?
        raise NotFoundError, ERROR_MESSAGES[:repository_not_found]
      end
    end

    override :user_access
    def user_access
      @user_access ||= UserAccessSnippet.new(user, snippet: snippet)
    end

    # TODO: Implement EE/Geo https://gitlab.com/gitlab-org/gitlab/issues/205629
    override :check_custom_action
    def check_custom_action(cmd)
      nil
    end
  end
end
