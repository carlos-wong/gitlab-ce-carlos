# frozen_string_literal: true

module IssuablesHelper
  include GitlabRoutingHelper

  def sidebar_gutter_toggle_icon
    content_tag(:span, class: 'js-sidebar-toggle-container', data: { is_expanded: !sidebar_gutter_collapsed? }) do
      sprite_icon('chevron-double-lg-left', css_class: "js-sidebar-expand #{'hidden' unless sidebar_gutter_collapsed?}") +
      sprite_icon('chevron-double-lg-right', css_class: "js-sidebar-collapse #{'hidden' if sidebar_gutter_collapsed?}")
    end
  end

  def sidebar_gutter_collapsed_class
    "right-sidebar-#{sidebar_gutter_collapsed? ? 'collapsed' : 'expanded'}"
  end

  def sidebar_gutter_tooltip_text
    sidebar_gutter_collapsed? ? _('Expand sidebar') : _('Collapse sidebar')
  end

  def assignees_label(issuable, include_value: true)
    label = 'Assignee'.pluralize(issuable.assignees.count)

    if include_value
      sanitized_list = sanitize_name(issuable.assignee_list)
      "#{label}: #{sanitized_list}"
    else
      label
    end
  end

  def sidebar_milestone_tooltip_label(milestone)
    return _('Milestone') unless milestone.present?

    [escape_once(milestone[:title]), sidebar_milestone_remaining_days(milestone) || _('Milestone')].join('<br/>')
  end

  def sidebar_milestone_remaining_days(milestone)
    due_date_with_remaining_days(milestone[:due_date], milestone[:start_date])
  end

  def sidebar_due_date_tooltip_label(due_date)
    [_('Due date'), due_date_with_remaining_days(due_date)].compact.join('<br/>')
  end

  def due_date_with_remaining_days(due_date, start_date = nil)
    return unless due_date

    "#{due_date.to_s(:medium)} (#{remaining_days_in_words(due_date, start_date)})"
  end

  def multi_label_name(current_labels, default_label)
    return default_label if current_labels.blank?

    title = current_labels.first.try(:title) || current_labels.first[:title]

    if current_labels.size > 1
      "#{title} +#{current_labels.size - 1} more"
    else
      title
    end
  end

  def issuable_json_path(issuable)
    project = issuable.project

    if issuable.is_a?(MergeRequest)
      project_merge_request_path(project, issuable.iid, :json)
    else
      project_issue_path(project, issuable.iid, :json)
    end
  end

  def serialize_issuable(issuable, opts = {})
    serializer_klass = case issuable
                       when Issue
                         IssueSerializer
                       when MergeRequest
                         opts[:experiment_enabled] = :suggest_pipeline if experiment_enabled?(:suggest_pipeline) && opts[:serializer] == 'widget'
                         MergeRequestSerializer
                       end

    serializer_klass
      .new(current_user: current_user, project: issuable.project)
      .represent(issuable, opts)
      .to_json
  end

  def template_dropdown_tag(issuable, &block)
    title = selected_template(issuable) || "Choose a template"
    options = {
      toggle_class: 'js-issuable-selector',
      title: title,
      filter: true,
      placeholder: 'Filter',
      footer_content: true,
      data: {
        data: issuable_templates(issuable),
        field_name: 'issuable_template',
        selected: selected_template(issuable),
        project_path: ref_project.path,
        namespace_path: ref_project.namespace.full_path
      }
    }

    dropdown_tag(title, options: options) do
      capture(&block)
    end
  end

  def users_dropdown_label(selected_users)
    case selected_users.length
    when 0
      "Unassigned"
    when 1
      selected_users[0].name
    else
      "#{selected_users[0].name} + #{selected_users.length - 1} more"
    end
  end

  # rubocop: disable CodeReuse/ActiveRecord
  def user_dropdown_label(user_id, default_label)
    return default_label if user_id.nil?
    return "Unassigned" if user_id == "0"

    user = User.find_by(id: user_id)

    if user
      user.name
    else
      default_label
    end
  end
  # rubocop: enable CodeReuse/ActiveRecord

  # rubocop: disable CodeReuse/ActiveRecord
  def project_dropdown_label(project_id, default_label)
    return default_label if project_id.nil?
    return "Any project" if project_id == "0"

    project = Project.find_by(id: project_id)

    if project
      project.full_name
    else
      default_label
    end
  end
  # rubocop: enable CodeReuse/ActiveRecord

  # rubocop: disable CodeReuse/ActiveRecord
  def group_dropdown_label(group_id, default_label)
    return default_label if group_id.nil?
    return "Any group" if group_id == "0"

    group = ::Group.find_by(id: group_id)

    if group
      group.full_name
    else
      default_label
    end
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def milestone_dropdown_label(milestone_title, default_label = "Milestone")
    title =
      case milestone_title
      when Milestone::Upcoming.name then Milestone::Upcoming.title
      when Milestone::Started.name then Milestone::Started.title
      else milestone_title.presence
      end

    h(title || default_label)
  end

  def to_url_reference(issuable)
    case issuable
    when Issue
      link_to issuable.to_reference, issue_url(issuable)
    when MergeRequest
      link_to issuable.to_reference, merge_request_url(issuable)
    else
      issuable.to_reference
    end
  end

  def issuable_meta(issuable, project, text)
    output = []
    output << "Opened #{time_ago_with_tooltip(issuable.created_at)} by ".html_safe

    output << content_tag(:strong) do
      author_output = link_to_member(project, issuable.author, size: 24, mobile_classes: "d-none d-sm-inline")
      author_output << link_to_member(project, issuable.author, size: 24, by_username: true, avatar: false, mobile_classes: "d-inline d-sm-none")

      author_output << issuable_meta_author_slot(issuable.author, css_class: 'ml-1')

      if status = user_status(issuable.author)
        author_output << "#{status}".html_safe
      end

      author_output
    end

    if access = project.team.human_max_access(issuable.author_id)
      output << content_tag(:span, access, class: "user-access-role has-tooltip d-none d-xl-inline-block gl-ml-3 ", title: _("This user has the %{access} role in the %{name} project.") % { access: access.downcase, name: project.name })
    elsif project.team.contributor?(issuable.author_id)
      output << content_tag(:span, _("Contributor"), class: "user-access-role has-tooltip d-none d-xl-inline-block gl-ml-3", title: _("This user has previously committed to the %{name} project.") % { name: project.name })
    end

    output << content_tag(:span, (sprite_icon('first-contribution', css_class: 'gl-icon gl-vertical-align-middle') if issuable.first_contribution?), class: 'has-tooltip gl-ml-2', title: _('1st contribution!'))

    output << content_tag(:span, (issuable.task_status if issuable.tasks?), id: "task_status", class: "d-none d-sm-none d-md-inline-block gl-ml-3")
    output << content_tag(:span, (issuable.task_status_short if issuable.tasks?), id: "task_status_short", class: "d-md-none")

    output.join.html_safe
  end

  # This is a dummy method, and has an override defined in ee
  def issuable_meta_author_slot(author, css_class: nil)
    nil
  end

  def issuables_state_counter_text(issuable_type, state, display_count)
    titles = {
      opened: "Open"
    }

    state_title = titles[state] || state.to_s.humanize
    html = content_tag(:span, state_title)

    if display_count
      count = issuables_count_for_state(issuable_type, state)
      tag =
        if count == -1
          tooltip = _("Couldn't calculate number of %{issuables}.") % { issuables: issuable_type.to_s.humanize(capitalize: false) }

          content_tag(
            :span,
            '?',
            class: 'badge badge-pill has-tooltip',
            aria: { label: tooltip },
            title: tooltip
          )
        else
          content_tag(:span, number_with_delimiter(count), class: 'badge badge-pill')
        end

      html << " " << tag
    end

    html.html_safe
  end

  def assigned_issuables_count(issuable_type)
    case issuable_type
    when :issues
      current_user.assigned_open_issues_count
    when :merge_requests
      current_user.assigned_open_merge_requests_count
    else
      raise ArgumentError, "invalid issuable `#{issuable_type}`"
    end
  end

  def issuable_reference(issuable)
    @show_full_reference ? issuable.to_reference(full: true) : issuable.to_reference(@group || @project)
  end

  def issuable_initial_data(issuable)
    data = {
      endpoint: issuable_path(issuable),
      updateEndpoint: "#{issuable_path(issuable)}.json",
      canUpdate: can?(current_user, :"update_#{issuable.to_ability_name}", issuable),
      canDestroy: can?(current_user, :"destroy_#{issuable.to_ability_name}", issuable),
      issuableRef: issuable.to_reference,
      issuableStatus: issuable.state,
      markdownPreviewPath: preview_markdown_path(parent),
      markdownDocsPath: help_page_path('user/markdown'),
      lockVersion: issuable.lock_version,
      issuableTemplateNamesPath: template_names_path(parent, issuable),
      initialTitleHtml: markdown_field(issuable, :title),
      initialTitleText: issuable.title,
      initialDescriptionHtml: markdown_field(issuable, :description),
      initialDescriptionText: issuable.description,
      initialTaskStatus: issuable.task_status
    }
    data.merge!(issue_only_initial_data(issuable))
    data.merge!(path_data(parent))
    data.merge!(updated_at_by(issuable))

    data
  end

  def issue_only_initial_data(issuable)
    return {} unless issuable.is_a?(Issue)

    {
      hasClosingMergeRequest: issuable.merge_requests_count(current_user) != 0,
      issueType: issuable.issue_type,
      zoomMeetingUrl: ZoomMeeting.canonical_meeting_url(issuable),
      sentryIssueIdentifier: SentryIssue.find_by(issue: issuable)&.sentry_issue_identifier, # rubocop:disable CodeReuse/ActiveRecord
      iid: issuable.iid.to_s
    }
  end

  def path_data(parent)
    return { groupPath: parent.path } if parent.is_a?(Group)

    {
      projectPath: ref_project.path,
      projectNamespace: ref_project.namespace.full_path
    }
  end

  def updated_at_by(issuable)
    return {} unless issuable.edited?

    {
      updatedAt: issuable.last_edited_at.to_time.iso8601,
      updatedBy: {
        name: issuable.last_edited_by.name,
        path: user_path(issuable.last_edited_by)
      }
    }
  end

  def issuables_count_for_state(issuable_type, state)
    Gitlab::IssuablesCountForState.new(finder)[state]
  end

  def close_issuable_path(issuable)
    issuable_path(issuable, close_reopen_params(issuable, :close))
  end

  def reopen_issuable_path(issuable)
    issuable_path(issuable, close_reopen_params(issuable, :reopen))
  end

  def close_reopen_issuable_path(issuable, should_inverse = false)
    issuable.closed? ^ should_inverse ? reopen_issuable_path(issuable) : close_issuable_path(issuable)
  end

  def toggle_draft_issuable_path(issuable)
    wip_event = issuable.work_in_progress? ? 'unwip' : 'wip'

    issuable_path(issuable, { merge_request: { wip_event: wip_event } })
  end

  def issuable_path(issuable, *options)
    polymorphic_path(issuable, *options)
  end

  def issuable_url(issuable, *options)
    case issuable
    when Issue
      issue_url(issuable, *options)
    when MergeRequest
      merge_request_url(issuable, *options)
    end
  end

  def issuable_button_visibility(issuable, closed)
    return 'hidden' if issuable_button_hidden?(issuable, closed)
  end

  def issuable_button_hidden?(issuable, closed)
    case issuable
    when Issue
      issue_button_hidden?(issuable, closed)
    when MergeRequest
      merge_request_button_hidden?(issuable, closed)
    end
  end

  def issuable_author_is_current_user(issuable)
    issuable.author == current_user
  end

  def issuable_display_type(issuable)
    issuable.model_name.human.downcase
  end

  def has_filter_bar_param?
    finder.class.scalar_params.any? { |p| params[p].present? }
  end

  def assignee_sidebar_data(assignee, merge_request: nil)
    { avatar_url: assignee.avatar_url, name: assignee.name, username: assignee.username }.tap do |data|
      data[:can_merge] = merge_request.can_be_merged_by?(assignee) if merge_request
    end
  end

  def reviewer_sidebar_data(reviewer, merge_request: nil)
    { avatar_url: reviewer.avatar_url, name: reviewer.name, username: reviewer.username }.tap do |data|
      data[:can_merge] = merge_request.can_be_merged_by?(reviewer) if merge_request
    end
  end

  def issuable_squash_option?(issuable, project)
    if issuable.persisted?
      issuable.squash
    else
      project.squash_enabled_by_default?
    end
  end

  private

  def sidebar_gutter_collapsed?
    cookies[:collapsed_gutter] == 'true'
  end

  def issuable_templates(issuable)
    @issuable_templates ||=
      case issuable
      when Issue
        ref_project.repository.issue_template_names
      when MergeRequest
        ref_project.repository.merge_request_template_names
      end
  end

  def issuable_templates_names(issuable)
    issuable_templates(issuable).map { |template| template[:name] }
  end

  def selected_template(issuable)
    params[:issuable_template] if issuable_templates(issuable).any? { |template| template[:name] == params[:issuable_template] }
  end

  def issuable_todo_button_data(issuable, is_collapsed)
    {
      todo_text: _('Add a to do'),
      mark_text: _('Mark as done'),
      todo_icon: sprite_icon('todo-add'),
      mark_icon: sprite_icon('todo-done', css_class: 'todo-undone'),
      issuable_id: issuable[:id],
      issuable_type: issuable[:type],
      create_path: issuable[:create_todo_path],
      delete_path: issuable.dig(:current_user, :todo, :delete_path),
      placement: is_collapsed ? 'left' : nil,
      container: is_collapsed ? 'body' : nil,
      boundary: 'viewport',
      is_collapsed: is_collapsed,
      track_label: "right_sidebar",
      track_property: "update_todo",
      track_event: "click_button",
      track_value: ""
    }
  end

  def close_reopen_params(issuable, action)
    {
      issuable.model_name.to_s.underscore => { state_event: action }
    }.tap do |params|
      params[:format] = :json if issuable.is_a?(Issue)
    end
  end

  def labels_path
    if @project
      project_labels_path(@project)
    elsif @group
      group_labels_path(@group)
    end
  end

  def template_names_path(parent, issuable)
    return '' unless parent.is_a?(Project)

    project_template_names_path(parent, template_type: issuable.class.name.underscore)
  end

  def issuable_sidebar_options(issuable)
    {
      endpoint: "#{issuable[:issuable_json_path]}?serializer=sidebar_extras",
      toggleSubscriptionEndpoint: issuable[:toggle_subscription_path],
      moveIssueEndpoint: issuable[:move_issue_path],
      projectsAutocompleteEndpoint: issuable[:projects_autocomplete_path],
      editable: issuable.dig(:current_user, :can_edit),
      assigneeable: issuable.dig(:current_user, :can_assignee),
      currentUser: issuable[:current_user],
      rootPath: root_path,
      fullPath: issuable[:project_full_path],
      iid: issuable[:iid],
      severity: issuable[:severity],
      timeTrackingLimitToHours: Gitlab::CurrentSettings.time_tracking_limit_to_hours
    }
  end

  def parent
    @project || @group
  end
end

IssuablesHelper.prepend_if_ee('EE::IssuablesHelper')
