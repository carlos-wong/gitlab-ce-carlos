# frozen_string_literal: true

module Gitlab
  module Auth
    Result = Struct.new(:actor, :project, :type, :authentication_abilities) do
      prepend_if_ee('::EE::Gitlab::Auth::Result') # rubocop: disable Cop/InjectEnterpriseEditionModule

      def ci?(for_project)
        type == :ci &&
          project &&
          project == for_project
      end

      def lfs_deploy_token?(for_project)
        type == :lfs_deploy_token &&
          actor.try(:has_access_to?, for_project)
      end

      def success?
        actor.present? || type == :ci
      end

      def failed?
        !success?
      end
    end
  end
end
