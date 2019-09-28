# frozen_string_literal: true

module MergeRequests
  class MergeBaseService < MergeRequests::BaseService
    include Gitlab::Utils::StrongMemoize

    MergeError = Class.new(StandardError)

    attr_reader :merge_request

    # Overridden in EE.
    def hooks_validation_pass?(_merge_request)
      true
    end

    # Overridden in EE.
    def hooks_validation_error(_merge_request)
      # No-op
    end

    def source
      if merge_request.squash
        squash_sha!
      else
        merge_request.diff_head_sha
      end
    end

    private

    def check_source
      unless source
        raise_error('No source for merge')
      end
    end

    # Overridden in EE.
    def check_size_limit
      # No-op
    end

    # Overridden in EE.
    def error_check!
      # No-op
    end

    def raise_error(message)
      raise MergeError, message
    end

    def handle_merge_error(*args)
      # No-op
    end

    def commit_message
      params[:commit_message] ||
        merge_request.default_merge_commit_message
    end

    def squash_sha!
      strong_memoize(:squash_sha) do
        params[:merge_request] = merge_request
        squash_result = ::MergeRequests::SquashService.new(project, current_user, params).execute

        case squash_result[:status]
        when :success
          squash_result[:squash_sha]
        when :error
          raise ::MergeRequests::MergeService::MergeError, squash_result[:message]
        end
      end
    end
  end
end

MergeRequests::MergeBaseService.prepend_if_ee('EE::MergeRequests::MergeBaseService')
