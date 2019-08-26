# frozen_string_literal: true

module Projects
  class MoveDeployKeysProjectsService < BaseMoveRelationsService
    def execute(source_project, remove_remaining_elements: true)
      return unless super

      Project.transaction(requires_new: true) do
        move_deploy_keys_projects
        remove_remaining_deploy_keys_projects if remove_remaining_elements

        success
      end
    end

    private

    def move_deploy_keys_projects
      non_existent_deploy_keys_projects.update_all(project_id: @project.id)
    end

    # rubocop: disable CodeReuse/ActiveRecord
    def non_existent_deploy_keys_projects
      source_project.deploy_keys_projects
                    .joins(:deploy_key)
                    .where.not(keys: { fingerprint: @project.deploy_keys.select(:fingerprint) })
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def remove_remaining_deploy_keys_projects
      source_project.deploy_keys_projects.destroy_all # rubocop: disable DestroyAll
    end
  end
end
