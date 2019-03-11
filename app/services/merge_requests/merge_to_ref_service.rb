# frozen_string_literal: true

module MergeRequests
  # Performs the merge between source SHA and the target branch. Instead
  # of writing the result to the MR target branch, it targets the `target_ref`.
  #
  # Ideally this should leave the `target_ref` state with the same state the
  # target branch would have if we used the regular `MergeService`, but without
  # every side-effect that comes with it (MR updates, mails, source branch
  # deletion, etc). This service should be kept idempotent (i.e. can
  # be executed regardless of the `target_ref` current state).
  #
  class MergeToRefService < MergeRequests::MergeBaseService
    def execute(merge_request)
      @merge_request = merge_request

      validate!

      commit_id = commit

      raise_error('Conflicts detected during merge') unless commit_id

      commit = project.commit(commit_id)
      target_id, source_id = commit.parent_ids

      success(commit_id: commit.id,
              target_id: target_id,
              source_id: source_id)
    rescue MergeError => error
      error(error.message)
    end

    private

    def validate!
      authorization_check!
      error_check!
    end

    def error_check!
      super

      error =
        if Feature.disabled?(:merge_to_tmp_merge_ref_path, project)
          'Feature is not enabled'
        elsif !hooks_validation_pass?(merge_request)
          hooks_validation_error(merge_request)
        elsif !@merge_request.mergeable_to_ref?
          "Merge request is not mergeable to #{target_ref}"
        elsif !source
          'No source for merge'
        end

      raise_error(error) if error
    end

    def authorization_check!
      unless Ability.allowed?(current_user, :admin_merge_request, project)
        raise_error("You are not allowed to merge to this ref")
      end
    end

    def target_ref
      merge_request.merge_ref_path
    end

    def commit
      repository.merge_to_ref(current_user, source, merge_request, target_ref, commit_message)
    rescue Gitlab::Git::PreReceiveError => error
      raise MergeError, error.message
    end
  end
end
