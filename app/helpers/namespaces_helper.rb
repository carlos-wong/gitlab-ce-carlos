# frozen_string_literal: true

module NamespacesHelper
  def namespace_id_from(params)
    params.dig(:project, :namespace_id) || params[:namespace_id]
  end

  def namespaces_options(selected = :current_user, display_path: false, groups: nil, extra_group: nil, groups_only: false)
    groups ||= current_user.manageable_groups_with_routes
    users = [current_user.namespace]
    selected_id = selected

    unless extra_group.nil? || extra_group.is_a?(Group)
      extra_group = Group.find(extra_group) if Namespace.find(extra_group).kind == 'group'
    end

    if extra_group && extra_group.is_a?(Group)
      extra_group = dedup_extra_group(extra_group)

      if Ability.allowed?(current_user, :read_group, extra_group)
        # Assign the value to an invalid primary ID so that the select box works
        extra_group.id = -1 unless extra_group.persisted?
        selected_id = extra_group.id if selected == :extra_group
        groups |= [extra_group]
      else
        selected_id = current_user.namespace.id
      end
    end

    options = []
    options << options_for_group(groups, display_path: display_path, type: 'group')

    unless groups_only
      options << options_for_group(users, display_path: display_path, type: 'user')

      if selected == :current_user && current_user.namespace
        selected_id = current_user.namespace.id
      end
    end

    grouped_options_for_select(options, selected_id)
  end

  def namespace_icon(namespace, size = 40)
    if namespace.is_a?(Group)
      group_icon_url(namespace)
    else
      avatar_icon_for_user(namespace.owner, size)
    end
  end

  def cascading_namespace_settings_popover_data(attribute, group, settings_path_helper)
    locked_by_ancestor = group.namespace_settings.public_send("#{attribute}_locked_by_ancestor?") # rubocop:disable GitlabSecurity/PublicSend

    popover_data = {
      locked_by_application_setting: group.namespace_settings.public_send("#{attribute}_locked_by_application_setting?"), # rubocop:disable GitlabSecurity/PublicSend
      locked_by_ancestor: locked_by_ancestor
    }

    if locked_by_ancestor
      ancestor_namespace = group.namespace_settings.public_send("#{attribute}_locked_ancestor").namespace # rubocop:disable GitlabSecurity/PublicSend

      popover_data[:ancestor_namespace] = {
        full_name: ancestor_namespace.full_name,
        path: settings_path_helper.call(ancestor_namespace)
      }
    end

    {
      popover_data: popover_data.to_json,
      testid: 'cascading-settings-lock-icon'
    }
  end

  def cascading_namespace_setting_locked?(attribute, group, **args)
    return false if group.nil?

    method_name = "#{attribute}_locked?"
    return false unless group.namespace_settings.respond_to?(method_name)

    group.namespace_settings.public_send(method_name, **args) # rubocop:disable GitlabSecurity/PublicSend
  end

  def namespaces_as_json(selected = :current_user)
    {
      group: formatted_namespaces(current_user.manageable_groups_with_routes),
      user: formatted_namespaces([current_user.namespace])
    }.to_json
  end

  def pipeline_usage_quota_app_data(namespace)
    {
      namespace_actual_plan_name: namespace.actual_plan_name,
      namespace_path: namespace.full_path,
      namespace_id: namespace.id,
      page_size: page_size
    }
  end

  private

  # Many importers create a temporary Group, so use the real
  # group if one exists by that name to prevent duplicates.
  # rubocop: disable CodeReuse/ActiveRecord
  def dedup_extra_group(extra_group)
    unless extra_group.persisted?
      existing_group = Group.find_by(path: extra_group.path)
      extra_group = existing_group if existing_group&.persisted?
    end

    extra_group
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def options_for_group(namespaces, display_path:, type:)
    group_label = type.pluralize
    elements = namespaces.sort_by(&:human_name).map! do |n|
      [display_path ? n.full_path : n.human_name, n.id,
       data: {
         options_parent: group_label,
         visibility_level: n.visibility_level_value,
         visibility: n.visibility,
         name: n.name,
         show_path: type == 'group' ? group_path(n) : user_path(n),
         edit_path: type == 'group' ? edit_group_path(n) : nil
       }]
    end

    [group_label.camelize, elements]
  end

  def formatted_namespaces(namespaces)
    namespaces.sort_by(&:human_name).map! do |n|
      {
        id: n.id,
        display_path: n.full_path,
        human_name: n.human_name,
        name: n.name
      }
    end
  end
end

NamespacesHelper.prepend_mod_with('NamespacesHelper')
