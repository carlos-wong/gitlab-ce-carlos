# frozen_string_literal: true

module MergeRequests
  class CreateService < MergeRequests::BaseService
    def execute
      set_projects!

      merge_request = MergeRequest.new
      merge_request.target_project = @project
      merge_request.source_project = @source_project
      merge_request.source_branch = params[:source_branch]

      create(merge_request)
    end

    def after_create(issuable)
      # Add new items to MergeRequests::AfterCreateService if they can
      # be performed in Sidekiq
      NewMergeRequestWorker.perform_async(issuable.id, current_user.id)

      todo_service.new_merge_request(issuable, current_user)
      issuable.cache_merge_request_closes_issues!(current_user)

      # https://gitlab.com/gitlab-org/gitlab/issues/208813
      unless ::Feature.enabled?(:create_merge_request_pipelines_in_sidekiq, project)
        create_pipeline_for(issuable, current_user)
        issuable.update_head_pipeline
      end

      Gitlab::UsageDataCounters::MergeRequestCounter.count(:create)
      link_lfs_objects(issuable)

      super
    end

    # expose issuable create method so it can be called from email
    # handler CreateMergeRequestHandler
    def create(merge_request)
      super
    end

    # Override from IssuableBaseService
    def handle_quick_actions_on_create(merge_request)
      super
      handle_wip_event(merge_request)
    end

    private

    def set_projects!
      # @project is used to determine whether the user can set the merge request's
      # assignee, milestone and labels. Whether they can depends on their
      # permissions on the target project.
      @source_project = @project
      @project = Project.find(params[:target_project_id]) if params[:target_project_id]

      # make sure that source/target project ids are not in
      # params so it can't be overridden later when updating attributes
      # from params when applying quick actions
      params.delete(:source_project_id)
      params.delete(:target_project_id)

      unless can?(current_user, :create_merge_request_from, @source_project) &&
          can?(current_user, :create_merge_request_in, @project)

        raise Gitlab::Access::AccessDeniedError
      end
    end

    def link_lfs_objects(issuable)
      LinkLfsObjectsService.new(issuable.target_project).execute(issuable)
    end
  end
end

MergeRequests::CreateService.include_if_ee('EE::MergeRequests::CreateService')
