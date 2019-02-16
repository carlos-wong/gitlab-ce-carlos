# frozen_string_literal: true

module MergeRequests
  class BaseService < ::IssuableBaseService
    def create_note(merge_request, state = merge_request.state)
      SystemNoteService.change_status(merge_request, merge_request.target_project, current_user, state, nil)
    end

    def hook_data(merge_request, action, old_rev: nil, old_associations: {})
      hook_data = merge_request.to_hook_data(current_user, old_associations: old_associations)
      hook_data[:object_attributes][:action] = action
      if old_rev && !Gitlab::Git.blank_ref?(old_rev)
        hook_data[:object_attributes][:oldrev] = old_rev
      end

      hook_data
    end

    def execute_hooks(merge_request, action = 'open', old_rev: nil, old_associations: {})
      if merge_request.project
        merge_data = hook_data(merge_request, action, old_rev: old_rev, old_associations: old_associations)
        merge_request.project.execute_hooks(merge_data, :merge_request_hooks)
        merge_request.project.execute_services(merge_data, :merge_request_hooks)
      end
    end

    private

    def handle_wip_event(merge_request)
      if wip_event = params.delete(:wip_event)
        # We update the title that is provided in the params or we use the mr title
        title = params[:title] || merge_request.title
        params[:title] = case wip_event
                         when 'wip' then MergeRequest.wip_title(title)
                         when 'unwip' then MergeRequest.wipless_title(title)
                         end
      end
    end

    def filter_params(merge_request)
      super

      unless merge_request.can_allow_collaboration?(current_user)
        params.delete(:allow_collaboration)
      end
    end

    def merge_request_metrics_service(merge_request)
      MergeRequestMetricsService.new(merge_request.metrics)
    end

    def create_assignee_note(merge_request)
      SystemNoteService.change_assignee(
        merge_request, merge_request.project, current_user, merge_request.assignee)
    end

    def create_merge_request_pipeline(merge_request, user)
      return unless Feature.enabled?(:ci_merge_request_pipeline,
                                     merge_request.source_project,
                                     default_enabled: true)

      ##
      # UpdateMergeRequestsWorker could be retried by an exception.
      # MR pipelines should not be recreated in such case.
      return if merge_request.merge_request_pipeline_exists?
      return if merge_request.has_no_commits?

      Ci::CreatePipelineService
        .new(merge_request.source_project, user, ref: merge_request.source_branch)
        .execute(:merge_request,
                 ignore_skip_ci: true,
                 save_on_errors: false,
                 merge_request: merge_request)
    end

    # Returns all origin and fork merge requests from `@project` satisfying passed arguments.
    # rubocop: disable CodeReuse/ActiveRecord
    def merge_requests_for(source_branch, mr_states: [:opened])
      @project.source_of_merge_requests
        .with_state(mr_states)
        .where(source_branch: source_branch)
        .preload(:source_project) # we don't need #includes since we're just preloading for the #select
        .select(&:source_project)
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def pipeline_merge_requests(pipeline)
      merge_requests_for(pipeline.ref).each do |merge_request|
        next unless pipeline == merge_request.head_pipeline

        yield merge_request
      end
    end

    def commit_status_merge_requests(commit_status)
      merge_requests_for(commit_status.ref).each do |merge_request|
        pipeline = merge_request.head_pipeline

        next unless pipeline
        next unless pipeline.sha == commit_status.sha

        yield merge_request
      end
    end
  end
end
