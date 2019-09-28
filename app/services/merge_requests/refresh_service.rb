# frozen_string_literal: true

module MergeRequests
  class RefreshService < MergeRequests::BaseService
    attr_reader :push

    def execute(oldrev, newrev, ref)
      @push = Gitlab::Git::Push.new(@project, oldrev, newrev, ref)
      return true unless @push.branch_push?

      refresh_merge_requests!
    end

    private

    def refresh_merge_requests!
      # n + 1: https://gitlab.com/gitlab-org/gitlab-foss/issues/60289
      Gitlab::GitalyClient.allow_n_plus_1_calls(&method(:find_new_commits))

      # Be sure to close outstanding MRs before reloading them to avoid generating an
      # empty diff during a manual merge
      close_upon_missing_source_branch_ref
      post_merge_manually_merged
      reload_merge_requests
      outdate_suggestions
      refresh_pipelines_on_merge_requests
      abort_auto_merges
      mark_pending_todos_done
      cache_merge_requests_closing_issues

      # Leave a system note if a branch was deleted/added
      if @push.branch_added? || @push.branch_removed?
        comment_mr_branch_presence_changed
      end

      notify_about_push
      mark_mr_as_wip_from_commits
      execute_mr_web_hooks

      true
    end

    def close_upon_missing_source_branch_ref
      # MergeRequest#reload_diff ignores not opened MRs. This means it won't
      # create an `empty` diff for `closed` MRs without a source branch, keeping
      # the latest diff state as the last _valid_ one.
      merge_requests_for_source_branch.reject(&:source_branch_exists?).each do |mr|
        MergeRequests::CloseService
          .new(mr.target_project, @current_user)
          .execute(mr)
      end
    end

    # Collect open merge requests that target same branch we push into
    # and close if push to master include last commit from merge request
    # We need this to close(as merged) merge requests that were merged into
    # target branch manually
    # rubocop: disable CodeReuse/ActiveRecord
    def post_merge_manually_merged
      commit_ids = @commits.map(&:id)
      merge_requests = @project.merge_requests.opened
        .preload(:latest_merge_request_diff)
        .where(target_branch: @push.branch_name).to_a
        .select(&:diff_head_commit)
        .select do |merge_request|
          commit_ids.include?(merge_request.diff_head_sha) &&
            merge_request.merge_request_diff.state != 'empty'
        end
      merge_requests = filter_merge_requests(merge_requests)

      return if merge_requests.empty?

      commit_analyze_enabled = Feature.enabled?(:branch_push_merge_commit_analyze, @project, default_enabled: true)
      if commit_analyze_enabled
        analyzer = Gitlab::BranchPushMergeCommitAnalyzer.new(
          @commits.reverse,
          relevant_commit_ids: merge_requests.map(&:diff_head_sha)
        )
      end

      merge_requests.each do |merge_request|
        if commit_analyze_enabled
          merge_request.merge_commit_sha = analyzer.get_merge_commit(merge_request.diff_head_sha)
        end

        MergeRequests::PostMergeService
          .new(merge_request.target_project, @current_user)
          .execute(merge_request)
      end
    end
    # rubocop: enable CodeReuse/ActiveRecord

    # Refresh merge request diff if we push to source or target branch of merge request
    # Note: we should update merge requests from forks too
    # rubocop: disable CodeReuse/ActiveRecord
    def reload_merge_requests
      merge_requests = @project.merge_requests.opened
        .by_source_or_target_branch(@push.branch_name).to_a

      # Fork merge requests
      merge_requests += MergeRequest.opened
        .where(source_branch: @push.branch_name, source_project: @project)
        .where.not(target_project: @project).to_a

      filter_merge_requests(merge_requests).each do |merge_request|
        if branch_and_project_match?(merge_request) || @push.force_push?
          merge_request.reload_diff(current_user)
        elsif merge_request.includes_any_commits?(push_commit_ids)
          merge_request.reload_diff(current_user)
        end

        merge_request.mark_as_unchecked
      end

      # Upcoming method calls need the refreshed version of
      # @source_merge_requests diffs (for MergeRequest#commit_shas for instance).
      merge_requests_for_source_branch(reload: true)
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def push_commit_ids
      @push_commit_ids ||= @commits.map(&:id)
    end

    def branch_and_project_match?(merge_request)
      merge_request.source_project == @project &&
        merge_request.source_branch == @push.branch_name
    end

    def outdate_suggestions
      outdate_service = Suggestions::OutdateService.new

      merge_requests_for_source_branch.each do |merge_request|
        outdate_service.execute(merge_request)
      end
    end

    def refresh_pipelines_on_merge_requests
      merge_requests_for_source_branch.each do |merge_request|
        create_pipeline_for(merge_request, current_user)
        UpdateHeadPipelineForMergeRequestWorker.perform_async(merge_request.id)
      end
    end

    def abort_auto_merges
      merge_requests_for_source_branch.each do |merge_request|
        abort_auto_merge(merge_request, 'source branch was updated')
      end
    end

    def mark_pending_todos_done
      merge_requests_for_source_branch.each do |merge_request|
        todo_service.merge_request_push(merge_request, @current_user)
      end
    end

    def find_new_commits
      if @push.branch_added?
        @commits = []

        merge_request = merge_requests_for_source_branch.first
        return unless merge_request

        begin
          # Since any number of commits could have been made to the restored branch,
          # find the common root to see what has been added.
          common_ref = @project.repository.merge_base(merge_request.diff_head_sha, @push.newrev)
          # If the a commit no longer exists in this repo, gitlab_git throws
          # a Rugged::OdbError. This is fixed in https://gitlab.com/gitlab-org/gitlab_git/merge_requests/52
          @commits = @project.repository.commits_between(common_ref, @push.newrev) if common_ref
        rescue
        end
      elsif @push.branch_removed?
        # No commits for a deleted branch.
        @commits = []
      else
        @commits = @project.repository.commits_between(@push.oldrev, @push.newrev)
      end
    end

    # Add comment about branches being deleted or added to merge requests
    def comment_mr_branch_presence_changed
      presence = @push.branch_added? ? :add : :delete

      merge_requests_for_source_branch.each do |merge_request|
        SystemNoteService.change_branch_presence(
          merge_request, merge_request.project, @current_user,
          :source, @push.branch_name, presence)
      end
    end

    # Add comment about pushing new commits to merge requests and send nofitication emails
    def notify_about_push
      return unless @commits.present?

      merge_requests_for_source_branch.each do |merge_request|
        mr_commit_ids = Set.new(merge_request.commit_shas)

        new_commits, existing_commits = @commits.partition do |commit|
          mr_commit_ids.include?(commit.id)
        end

        SystemNoteService.add_commits(merge_request, merge_request.project,
                                      @current_user, new_commits,
                                      existing_commits, @push.oldrev)

        notification_service.push_to_merge_request(merge_request, @current_user, new_commits: new_commits, existing_commits: existing_commits)
      end
    end

    def mark_mr_as_wip_from_commits
      return unless @commits.present?

      merge_requests_for_source_branch.each do |merge_request|
        commit_shas = merge_request.commit_shas

        wip_commit = @commits.detect do |commit|
          commit.work_in_progress? && commit_shas.include?(commit.sha)
        end

        if wip_commit && !merge_request.work_in_progress?
          merge_request.update(title: merge_request.wip_title)
          SystemNoteService.add_merge_request_wip_from_commit(
            merge_request,
            merge_request.project,
            @current_user,
            wip_commit
          )
        end
      end
    end

    # Call merge request webhook with update branches
    def execute_mr_web_hooks
      merge_requests_for_source_branch.each do |merge_request|
        execute_hooks(merge_request, 'update', old_rev: @push.oldrev)
      end
    end

    # If the merge requests closes any issues, save this information in the
    # `MergeRequestsClosingIssues` model (as a performance optimization).
    # rubocop: disable CodeReuse/ActiveRecord
    def cache_merge_requests_closing_issues
      @project.merge_requests.where(source_branch: @push.branch_name).each do |merge_request|
        merge_request.cache_merge_request_closes_issues!(@current_user)
      end
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def filter_merge_requests(merge_requests)
      merge_requests.uniq.select(&:source_project)
    end

    def merge_requests_for_source_branch(reload: false)
      @source_merge_requests = nil if reload
      @source_merge_requests ||= merge_requests_for(@push.branch_name)
    end
  end
end

MergeRequests::RefreshService.prepend_if_ee('EE::MergeRequests::RefreshService')
