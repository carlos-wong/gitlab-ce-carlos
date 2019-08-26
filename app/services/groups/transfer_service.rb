# frozen_string_literal: true

module Groups
  class TransferService < Groups::BaseService
    ERROR_MESSAGES = {
      database_not_supported: s_('TransferGroup|Database is not supported.'),
      namespace_with_same_path: s_('TransferGroup|The parent group already has a subgroup with the same path.'),
      group_is_already_root: s_('TransferGroup|Group is already a root group.'),
      same_parent_as_current: s_('TransferGroup|Group is already associated to the parent group.'),
      invalid_policies: s_("TransferGroup|You don't have enough permissions.")
    }.freeze

    TransferError = Class.new(StandardError)

    attr_reader :error

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
      Group.transaction do
        update_group_attributes
        ensure_ownership
      end

      true
    end

    def ensure_allowed_transfer
      raise_transfer_error(:group_is_already_root) if group_is_already_root?
      raise_transfer_error(:same_parent_as_current) if same_parent?
      raise_transfer_error(:invalid_policies) unless valid_policies?
      raise_transfer_error(:namespace_with_same_path) if namespace_with_same_path?
    end

    def group_is_already_root?
      !@new_parent_group && !@group.has_parent?
    end

    def same_parent?
      @new_parent_group && @new_parent_group.id == @group.parent_id
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

    def update_group_attributes
      if @new_parent_group && @new_parent_group.visibility_level < @group.visibility_level
        update_children_and_projects_visibility
        @group.visibility_level = @new_parent_group.visibility_level
      end

      @group.parent = @new_parent_group
      @group.save!
    end

    # rubocop: disable CodeReuse/ActiveRecord
    def update_children_and_projects_visibility
      descendants = @group.descendants.where("visibility_level > ?", @new_parent_group.visibility_level)

      Group
        .where(id: descendants.select(:id))
        .update_all(visibility_level: @new_parent_group.visibility_level)

      @group
        .all_projects
        .where("visibility_level > ?", @new_parent_group.visibility_level)
        .update_all(visibility_level: @new_parent_group.visibility_level)
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def ensure_ownership
      return if @new_parent_group
      return unless @group.owners.empty?

      @group.add_owner(current_user)
    end

    def raise_transfer_error(message)
      raise TransferError, ERROR_MESSAGES[message]
    end
  end
end
