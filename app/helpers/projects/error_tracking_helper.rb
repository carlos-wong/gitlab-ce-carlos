# frozen_string_literal: true

module Projects::ErrorTrackingHelper
  def error_tracking_data(current_user, project)
    error_tracking_enabled = !!project.error_tracking_setting&.enabled?

    {
      'index-path' => project_error_tracking_index_path(project,
                                                        format: :json),
      'user-can-enable-error-tracking' => can?(current_user, :admin_operations, project).to_s,
      'enable-error-tracking-link' => project_settings_operations_path(project),
      'error-tracking-enabled' => error_tracking_enabled.to_s,
      'project-path' => project.full_path,
      'list-path' => project_error_tracking_index_path(project),
      'illustration-path' => image_path('illustrations/cluster_popover.svg')
    }
  end

  def error_details_data(project, issue_id)
    opts = [project, issue_id, { format: :json }]

    {
      'issue-id' => issue_id,
      'project-path' => project.full_path,
      'issue-update-path' => update_project_error_tracking_index_path(*opts),
      'project-issues-path' => project_issues_path(project),
      'issue-stack-trace-path' => stack_trace_project_error_tracking_index_path(*opts)
    }
  end
end
