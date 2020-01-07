# frozen_string_literal: true

module Gitlab
  module GitAccessResult
    class CustomAction
      attr_reader :payload, :console_messages

      # Example of payload:
      #
      # {
      #   'action' => 'geo_proxy_to_primary',
      #   'data' => {
      #     'api_endpoints' => %w{geo/proxy_git_push_ssh/info_refs geo/proxy_git_push_ssh/push},
      #     'gl_username' => user.username,
      #     'primary_repo' => geo_primary_http_url_to_repo(project_or_wiki)
      #   }
      # }
      #
      def initialize(payload, console_messages)
        @payload = payload
        @console_messages = console_messages
      end
    end
  end
end
