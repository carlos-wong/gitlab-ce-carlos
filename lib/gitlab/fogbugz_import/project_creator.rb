# frozen_string_literal: true

module Gitlab
  module FogbugzImport
    class ProjectCreator
      attr_reader :repo, :fb_session, :namespace, :current_user, :user_map

      def initialize(repo, fb_session, namespace, current_user, user_map = nil)
        @repo = repo
        @fb_session = fb_session
        @namespace = namespace
        @current_user = current_user
        @user_map = user_map
      end

      def execute
        ::Projects::CreateService.new(
          current_user,
          name: repo.safe_name,
          path: repo.path,
          namespace: namespace,
          creator: current_user,
          visibility_level: Gitlab::VisibilityLevel::PRIVATE,
          import_type: 'fogbugz',
          import_source: repo.name,
          import_url: Project::UNKNOWN_IMPORT_URL,
          import_data: { data: { 'repo' => repo.raw_data, 'user_map' => user_map }, credentials: { fb_session: fb_session } }
        ).execute
      end
    end
  end
end
