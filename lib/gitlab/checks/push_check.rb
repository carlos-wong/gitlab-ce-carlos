# frozen_string_literal: true

module Gitlab
  module Checks
    class PushCheck < BaseChecker
      def validate!
        logger.log_timed("Checking if you are allowed to push...") do
          unless can_push?
            raise GitAccess::UnauthorizedError, GitAccess::ERROR_MESSAGES[:push_code]
          end
        end
      end

      private

      def can_push?
        user_access.can_do_action?(:push_code) ||
          project.branch_allows_collaboration?(user_access.user, branch_name)
      end
    end
  end
end
