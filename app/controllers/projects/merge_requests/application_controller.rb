# frozen_string_literal: true

class Projects::MergeRequests::ApplicationController < Projects::ApplicationController
  before_action :check_merge_requests_available!
  before_action :merge_request
  before_action :authorize_read_merge_request!

  private

  # rubocop: disable CodeReuse/ActiveRecord
  def merge_request
    @issuable = @merge_request ||= @project.merge_requests.includes(author: :status).find_by!(iid: params[:id])
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def merge_request_params
    params.require(:merge_request).permit(merge_request_params_attributes)
  end

  def merge_request_params_attributes
    [
      :allow_collaboration,
      :assignee_id,
      :description,
      :force_remove_source_branch,
      :lock_version,
      :milestone_id,
      :source_branch,
      :source_project_id,
      :state_event,
      :squash,
      :target_branch,
      :target_project_id,
      :task_num,
      :title,
      :discussion_locked,
      label_ids: []
    ]
  end

  def set_pipeline_variables
    @pipelines =
      if can?(current_user, :read_pipeline, @project)
        @merge_request.all_pipelines
      else
        Ci::Pipeline.none
      end
  end
end
