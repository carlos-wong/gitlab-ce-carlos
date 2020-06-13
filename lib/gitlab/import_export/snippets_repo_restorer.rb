# frozen_string_literal: true

module Gitlab
  module ImportExport
    class SnippetsRepoRestorer
      def initialize(project:, shared:, user:)
        @project = project
        @shared = shared
        @user = user
      end

      def restore
        return true unless Feature.enabled?(:version_snippets, @user)
        return true unless Dir.exist?(snippets_repo_bundle_path)

        @project.snippets.find_each.all? do |snippet|
          Gitlab::ImportExport::SnippetRepoRestorer.new(snippet: snippet,
                                                        user: @user,
                                                        shared: @shared,
                                                        path_to_bundle: snippet_repo_bundle_path(snippet))
                                                   .restore
        end
      end

      private

      def snippet_repo_bundle_path(snippet)
        File.join(snippets_repo_bundle_path, ::Gitlab::ImportExport.snippet_repo_bundle_filename_for(snippet))
      end

      def snippets_repo_bundle_path
        @snippets_repo_bundle_path ||= ::Gitlab::ImportExport.snippets_repo_bundle_path(@shared.export_path)
      end
    end
  end
end
