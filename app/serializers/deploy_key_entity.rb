# frozen_string_literal: true

class DeployKeyEntity < Grape::Entity
  expose :id
  expose :user_id
  expose :title
  expose :fingerprint
  expose :destroyed_when_orphaned?, as: :destroyed_when_orphaned
  expose :almost_orphaned?, as: :almost_orphaned
  expose :created_at
  expose :updated_at
  expose :deploy_keys_projects, using: DeployKeysProjectEntity do |deploy_key|
    deploy_key.deploy_keys_projects.select do |deploy_key_project|
      !deploy_key_project.project&.pending_delete? &&
        Ability.allowed?(options[:user], :read_project, deploy_key_project.project)
    end
  end
  expose :can_edit

  private

  def can_edit
    Ability.allowed?(options[:user], :update_deploy_key, object) ||
      Ability.allowed?(options[:user], :update_deploy_keys_project, object.deploy_keys_project_for(options[:project]))
  end
end
