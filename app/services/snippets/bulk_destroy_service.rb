# frozen_string_literal: true

module Snippets
  class BulkDestroyService
    include Gitlab::Allowable

    attr_reader :current_user, :snippets

    DeleteRepositoryError = Class.new(StandardError)
    SnippetAccessError = Class.new(StandardError)

    def initialize(user, snippets)
      @current_user = user
      @snippets = snippets
    end

    def execute
      return ServiceResponse.success(message: 'No snippets found.') if snippets.empty?

      user_can_delete_snippets!
      attempt_delete_repositories!
      snippets.destroy_all # rubocop: disable DestroyAll

      ServiceResponse.success(message: 'Snippets were deleted.')
    rescue SnippetAccessError
      service_response_error("You don't have access to delete these snippets.", 403)
    rescue DeleteRepositoryError
      attempt_rollback_repositories
      service_response_error('Failed to delete snippet repositories.', 400)
    rescue
      # In case the delete operation fails
      attempt_rollback_repositories
      service_response_error('Failed to remove snippets.', 400)
    end

    private

    def user_can_delete_snippets!
      allowed = DeclarativePolicy.user_scope do
        snippets.find_each.all? { |snippet| user_can_delete_snippet?(snippet) }
      end

      raise SnippetAccessError unless allowed
    end

    def user_can_delete_snippet?(snippet)
      can?(current_user, :admin_snippet, snippet)
    end

    def attempt_delete_repositories!
      snippets.each do |snippet|
        result = Repositories::DestroyService.new(snippet.repository).execute

        raise DeleteRepositoryError if result[:status] == :error
      end
    end

    def attempt_rollback_repositories
      snippets.each do |snippet|
        result = Repositories::DestroyRollbackService.new(snippet.repository).execute

        log_rollback_error(snippet) if result[:status] == :error
      end
    end

    def log_rollback_error(snippet)
      Gitlab::AppLogger.error("Repository #{snippet.full_path} in path #{snippet.disk_path} could not be rolled back")
    end

    def service_response_error(message, http_status)
      ServiceResponse.error(message: message, http_status: http_status)
    end
  end
end
