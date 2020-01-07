# frozen_string_literal: true

# Projects::TransferService class
#
# Used for transfer project to another namespace
#
# Ex.
#   # Move projects to namespace with ID 17 by user
#   Projects::TransferService.new(project, user, namespace_id: 17).execute
#
module Projects
  class TransferService < BaseService
    include Gitlab::ShellAdapter
    TransferError = Class.new(StandardError)

    attr_reader :new_namespace

    def execute(new_namespace)
      @new_namespace = new_namespace

      if @new_namespace.blank?
        raise TransferError, s_('TransferProject|Please select a new namespace for your project.')
      end

      unless allowed_transfer?(current_user, project)
        raise TransferError, s_('TransferProject|Transfer failed, please contact an admin.')
      end

      transfer(project)

      current_user.invalidate_personal_projects_count

      true
    rescue Projects::TransferService::TransferError => ex
      project.reset
      project.errors.add(:new_namespace, ex.message)
      false
    end

    private

    # rubocop: disable CodeReuse/ActiveRecord
    def transfer(project)
      @old_path = project.full_path
      @old_group = project.group
      @new_path = File.join(@new_namespace.try(:full_path) || '', project.path)
      @old_namespace = project.namespace

      if Project.where(namespace_id: @new_namespace.try(:id)).where('path = ? or name = ?', project.path, project.name).exists?
        raise TransferError.new(s_("TransferProject|Project with same name or path in target namespace already exists"))
      end

      if project.has_container_registry_tags?
        # We currently don't support renaming repository if it contains tags in container registry
        raise TransferError.new(s_('TransferProject|Project cannot be transferred, because tags are present in its container registry'))
      end

      attempt_transfer_transaction
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def attempt_transfer_transaction
      Project.transaction do
        project.expire_caches_before_rename(@old_path)

        update_namespace_and_visibility(@new_namespace)

        # Notifications
        project.send_move_instructions(@old_path)

        # Directories on disk
        move_project_folders(project)

        # Move missing group labels to project
        Labels::TransferService.new(current_user, @old_group, project).execute

        # Move missing group milestones
        Milestones::TransferService.new(current_user, @old_group, project).execute

        # Move uploads
        move_project_uploads(project)

        # Move pages
        Gitlab::PagesTransfer.new.move_project(project.path, @old_namespace.full_path, @new_namespace.full_path)

        project.old_path_with_namespace = @old_path

        update_repository_configuration(@new_path)

        execute_system_hooks
      end
    rescue Exception # rubocop:disable Lint/RescueException
      rollback_side_effects
      raise
    ensure
      refresh_permissions
    end

    def allowed_transfer?(current_user, project)
      @new_namespace &&
        can?(current_user, :change_namespace, project) &&
        @new_namespace.id != project.namespace_id &&
        current_user.can?(:transfer_projects, @new_namespace)
    end

    def update_namespace_and_visibility(to_namespace)
      # Apply new namespace id and visibility level
      project.namespace = to_namespace
      project.visibility_level = to_namespace.visibility_level unless project.visibility_level_allowed_by_group?
      project.save!
    end

    def update_repository_configuration(full_path)
      project.write_repository_config(gl_full_path: full_path)
      project.track_project_repository
    end

    def refresh_permissions
      # This ensures we only schedule 1 job for every user that has access to
      # the namespaces.
      user_ids = @old_namespace.user_ids_for_project_authorizations |
        @new_namespace.user_ids_for_project_authorizations

      UserProjectAccessChangedService.new(user_ids).execute
    end

    def rollback_side_effects
      rollback_folder_move
      project.reset
      update_namespace_and_visibility(@old_namespace)
      update_repository_configuration(@old_path)
    end

    def rollback_folder_move
      move_repo_folder(@new_path, @old_path)
      move_repo_folder("#{@new_path}.wiki", "#{@old_path}.wiki")
    end

    def move_repo_folder(from_name, to_name)
      gitlab_shell.mv_repository(project.repository_storage, from_name, to_name)
    end

    def execute_system_hooks
      SystemHooksService.new.execute_hooks_for(project, :transfer)
    end

    def move_project_folders(project)
      return if project.hashed_storage?(:repository)

      # Move main repository
      unless move_repo_folder(@old_path, @new_path)
        raise TransferError.new(s_("TransferProject|Cannot move project"))
      end

      # Disk path is changed; we need to ensure we reload it
      project.reload_repository!

      # Move wiki repo also if present
      move_repo_folder("#{@old_path}.wiki", "#{@new_path}.wiki")
    end

    def move_project_uploads(project)
      return if project.hashed_storage?(:attachments)

      Gitlab::UploadsTransfer.new.move_project(
        project.path,
        @old_namespace.full_path,
        @new_namespace.full_path
      )
    end
  end
end

Projects::TransferService.prepend_if_ee('EE::Projects::TransferService')
