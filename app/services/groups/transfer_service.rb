# frozen_string_literal: true

module Groups
  class TransferService < Groups::BaseService
    TransferError = Class.new(StandardError)

    attr_reader :error, :new_parent_group

    def initialize(group, user, params = {})
      super
      @error = nil
    end

    def execute(new_parent_group)
      @new_parent_group = new_parent_group
      ensure_allowed_transfer
      proceed_to_transfer

    rescue TransferError, ActiveRecord::RecordInvalid, Gitlab::UpdatePathError => e
      @group.errors.clear
      @error = s_("TransferGroup|Transfer failed: %{error_message}") % { error_message: e.message }
      false
    end

    private

    def proceed_to_transfer
      old_root_ancestor_id = @group.root_ancestor.id
      was_root_group = @group.root?

      Group.transaction do
        update_group_attributes
        ensure_ownership
        update_integrations
        remove_issue_contacts(old_root_ancestor_id, was_root_group)
        update_crm_objects(was_root_group)
      end

      post_update_hooks(@updated_project_ids)
      propagate_integrations
      update_pending_builds

      true
    end

    # Overridden in EE
    def post_update_hooks(updated_project_ids)
      refresh_project_authorizations
      refresh_descendant_groups if @new_parent_group
    end

    def ensure_allowed_transfer
      raise_transfer_error(:group_is_already_root) if group_is_already_root?
      raise_transfer_error(:same_parent_as_current) if same_parent?
      raise_transfer_error(:has_subscription) if has_subscription?
      raise_transfer_error(:invalid_policies) unless valid_policies?
      raise_transfer_error(:namespace_with_same_path) if namespace_with_same_path?
      raise_transfer_error(:group_contains_images) if group_projects_contain_registry_images?
      raise_transfer_error(:cannot_transfer_to_subgroup) if transfer_to_subgroup?
      raise_transfer_error(:group_contains_npm_packages) if group_with_npm_packages?
      raise_transfer_error(:no_permissions_to_migrate_crm) if no_permissions_to_migrate_crm?
    end

    def no_permissions_to_migrate_crm?
      return false unless group && @new_parent_group
      return false if group.root_ancestor == @new_parent_group.root_ancestor

      return true if group.contacts.exists? && !current_user.can?(:admin_crm_contact, @new_parent_group.root_ancestor)
      return true if group.organizations.exists? && !current_user.can?(:admin_crm_organization, @new_parent_group.root_ancestor)

      false
    end

    def group_with_npm_packages?
      return false unless group.packages_feature_enabled?

      npm_packages = ::Packages::GroupPackagesFinder.new(current_user, group, package_type: :npm).execute

      different_root_ancestor? && npm_packages.exists?
    end

    def different_root_ancestor?
      group.root_ancestor != new_parent_group&.root_ancestor
    end

    def group_is_already_root?
      !@new_parent_group && !@group.has_parent?
    end

    def same_parent?
      @new_parent_group && @new_parent_group.id == @group.parent_id
    end

    def has_subscription?
      @group.paid?
    end

    def transfer_to_subgroup?
      @new_parent_group && \
      @group.self_and_descendants.pluck_primary_key.include?(@new_parent_group.id)
    end

    def valid_policies?
      return false unless can?(current_user, :admin_group, @group)

      if @new_parent_group
        can?(current_user, :create_subgroup, @new_parent_group)
      else
        can?(current_user, :create_group)
      end
    end

    # rubocop: disable CodeReuse/ActiveRecord
    def namespace_with_same_path?
      Namespace.exists?(path: @group.path, parent: @new_parent_group)
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def group_projects_contain_registry_images?
      @group.has_container_repository_including_subgroups?
    end

    def update_group_attributes
      if @new_parent_group && @new_parent_group.visibility_level < @group.visibility_level
        update_children_and_projects_visibility
        @group.visibility_level = @new_parent_group.visibility_level
      end

      update_two_factor_authentication if @new_parent_group

      @group.parent = @new_parent_group
      @group.clear_memoization(:self_and_ancestors_ids)
      @group.clear_memoization(:root_ancestor) if different_root_ancestor?

      inherit_group_shared_runners_settings

      @group.save!
      # #reload is called to make sure traversal_ids are reloaded
      @group.reload # rubocop:disable Cop/ActiveRecordAssociationReload
    end

    # rubocop: disable CodeReuse/ActiveRecord
    def update_children_and_projects_visibility
      descendants = @group.descendants.where("visibility_level > ?", @new_parent_group.visibility_level)

      Group
        .where(id: descendants.select(:id))
        .update_all(visibility_level: @new_parent_group.visibility_level)

      projects_to_update = @group
        .all_projects
        .where("visibility_level > ?", @new_parent_group.visibility_level)

      # Used in post_update_hooks in EE. Must use pluck (and not select)
      # here as after we perform the update below we won't be able to find
      # these records again.
      @updated_project_ids = projects_to_update.pluck(:id)

      Namespaces::ProjectNamespace
        .where(id: projects_to_update.select(:project_namespace_id))
        .update_all(visibility_level: @new_parent_group.visibility_level)

      projects_to_update
        .update_all(visibility_level: @new_parent_group.visibility_level)

      update_project_settings(@updated_project_ids)
    end

    # Overridden in EE
    def update_project_settings(updated_project_ids)
    end

    def update_two_factor_authentication
      return if namespace_parent_allows_two_factor_auth

      @group.require_two_factor_authentication = false
    end

    def refresh_descendant_groups
      return if namespace_parent_allows_two_factor_auth

      if @group.descendants.where(require_two_factor_authentication: true).any?
        DisallowTwoFactorForSubgroupsWorker.perform_async(@group.id)
      end
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def namespace_parent_allows_two_factor_auth
      @new_parent_group.namespace_settings.allow_mfa_for_subgroups
    end

    def ensure_ownership
      return if @new_parent_group
      return unless @group.owners.empty?

      @group.add_owner(current_user)
    end

    def refresh_project_authorizations
      project_ids = Groups::ProjectsRequiringAuthorizationsRefresh::OnTransferFinder.new(@group).execute

      AuthorizedProjectUpdate::ProjectAccessChangedService.new(project_ids).execute
    end

    def raise_transfer_error(message)
      raise TransferError, localized_error_messages[message]
    end

    def localized_error_messages
      {
        database_not_supported: s_('TransferGroup|Database is not supported.'),
        namespace_with_same_path: s_('TransferGroup|The parent group already has a subgroup or a project with the same path.'),
        group_is_already_root: s_('TransferGroup|Group is already a root group.'),
        same_parent_as_current: s_('TransferGroup|Group is already associated to the parent group.'),
        invalid_policies: s_("TransferGroup|You don't have enough permissions."),
        group_contains_images: s_('TransferGroup|Cannot update the path because there are projects under this group that contain Docker images in their Container Registry. Please remove the images from your projects first and try again.'),
        cannot_transfer_to_subgroup: s_('TransferGroup|Cannot transfer group to one of its subgroup.'),
        group_contains_npm_packages: s_('TransferGroup|Group contains projects with NPM packages.'),
        no_permissions_to_migrate_crm: s_("TransferGroup|Group contains contacts/organizations and you don't have enough permissions to move them to the new root group.")
      }.freeze
    end

    def inherit_group_shared_runners_settings
      parent_setting = @group.parent&.shared_runners_setting
      return unless parent_setting

      if @group.shared_runners_setting_higher_than?(parent_setting)
        result = Groups::UpdateSharedRunnersService.new(@group, current_user, shared_runners_setting: parent_setting).execute

        raise TransferError, result[:message] unless result[:status] == :success
      end
    end

    def update_integrations
      @group.integrations.with_default_settings.delete_all
      Integration.create_from_active_default_integrations(@group, :group_id)
    end

    def propagate_integrations
      @group.integrations.with_default_settings.each do |integration|
        PropagateIntegrationWorker.perform_async(integration.id)
      end
    end

    def update_pending_builds
      ::Ci::PendingBuilds::UpdateGroupWorker.perform_async(group.id, pending_builds_params)
    end

    def pending_builds_params
      {
        namespace_traversal_ids: group.traversal_ids,
        namespace_id: group.id
      }
    end

    def update_crm_objects(was_root_group)
      return unless was_root_group

      CustomerRelations::Contact.move_to_root_group(group)
      CustomerRelations::Organization.move_to_root_group(group)
    end

    def remove_issue_contacts(old_root_ancestor_id, was_root_group)
      return if was_root_group
      return if old_root_ancestor_id == @group.root_ancestor.id

      CustomerRelations::IssueContact.delete_for_group(@group)
    end
  end
end

Groups::TransferService.prepend_mod_with('Groups::TransferService')
