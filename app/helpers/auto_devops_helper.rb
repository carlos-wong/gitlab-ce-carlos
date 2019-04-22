# frozen_string_literal: true

module AutoDevopsHelper
  def show_auto_devops_callout?(project)
    Feature.get(:auto_devops_banner_disabled).off? &&
      show_callout?('auto_devops_settings_dismissed') &&
      can?(current_user, :admin_pipeline, project) &&
      project.has_auto_devops_implicitly_disabled? &&
      !project.repository.gitlab_ci_yml &&
      !project.ci_service
  end

  def badge_for_auto_devops_scope(auto_devops_receiver)
    return unless auto_devops_receiver.auto_devops_enabled?

    case auto_devops_receiver.first_auto_devops_config[:scope]
    when :project
      nil
    when :group
      s_('CICD|group enabled')
    when :instance
      s_('CICD|instance enabled')
    end
  end
end
