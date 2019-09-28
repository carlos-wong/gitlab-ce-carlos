# frozen_string_literal: true

module Gitlab
  module Checks
    class ChangeAccess
      prepend_if_ee('EE::Gitlab::Checks::ChangeAccess') # rubocop: disable Cop/InjectEnterpriseEditionModule

      ATTRIBUTES = %i[user_access project skip_authorization
                      skip_lfs_integrity_check protocol oldrev newrev ref
                      branch_name tag_name logger commits].freeze

      attr_reader(*ATTRIBUTES)

      def initialize(
        change, user_access:, project:,
        skip_lfs_integrity_check: false, protocol:, logger:
      )
        @oldrev, @newrev, @ref = change.values_at(:oldrev, :newrev, :ref)
        @branch_name = Gitlab::Git.branch_name(@ref)
        @tag_name = Gitlab::Git.tag_name(@ref)
        @user_access = user_access
        @project = project
        @skip_lfs_integrity_check = skip_lfs_integrity_check
        @protocol = protocol

        @logger = logger
        @logger.append_message("Running checks for ref: #{@branch_name || @tag_name}")
      end

      def exec
        ref_level_checks
        # Check of commits should happen as the last step
        # given they're expensive in terms of performance
        commits_check

        true
      end

      def commits
        @commits ||= project.repository.new_commits(newrev)
      end

      protected

      def ref_level_checks
        Gitlab::Checks::PushCheck.new(self).validate!
        Gitlab::Checks::BranchCheck.new(self).validate!
        Gitlab::Checks::TagCheck.new(self).validate!
        Gitlab::Checks::LfsCheck.new(self).validate!
      end

      def commits_check
        Gitlab::Checks::DiffCheck.new(self).validate!
      end
    end
  end
end
