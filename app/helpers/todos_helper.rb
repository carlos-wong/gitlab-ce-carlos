# frozen_string_literal: true

module TodosHelper
  def todos_pending_count
    @todos_pending_count ||= current_user.todos_pending_count
  end

  def todos_count_format(count)
    count > 99 ? '99+' : count.to_s
  end

  def todos_done_count
    @todos_done_count ||= current_user.todos_done_count
  end

  def todo_action_name(todo)
    case todo.action
    when Todo::ASSIGNED then todo.self_added? ? 'assigned' : 'assigned you'
    when Todo::MENTIONED then "mentioned #{todo_action_subject(todo)} on"
    when Todo::BUILD_FAILED then 'The build failed for'
    when Todo::MARKED then 'added a todo for'
    when Todo::APPROVAL_REQUIRED then "set #{todo_action_subject(todo)} as an approver for"
    when Todo::UNMERGEABLE then 'Could not merge'
    when Todo::DIRECTLY_ADDRESSED then "directly addressed #{todo_action_subject(todo)} on"
    end
  end

  def todo_target_link(todo)
    text = raw(todo_target_type_name(todo) + ' ') +
      if todo.for_commit?
        content_tag(:span, todo.target_reference, class: 'commit-sha')
      else
        todo.target_reference
      end

    link_to text, todo_target_path(todo)
  end

  def todo_target_title(todo)
    if todo.target
      "\"#{todo.target.title}\""
    else
      ""
    end
  end

  def todo_parent_path(todo)
    if todo.parent.is_a?(Group)
      link_to todo.parent.name, group_path(todo.parent)
    else
      link_to_project(todo.project)
    end
  end

  def todo_target_type_name(todo)
    todo.target_type.titleize.downcase
  end

  def todo_target_path(todo)
    return unless todo.target.present?

    path_options = todo_target_path_options(todo)

    if todo.for_commit?
      project_commit_path(todo.project, todo.target, path_options)
    else
      path = [todo.parent, todo.target]

      path.unshift(:pipelines) if todo.build_failed?

      polymorphic_path(path, path_options)
    end
  end

  def todo_target_path_options(todo)
    { anchor: todo_target_path_anchor(todo) }
  end

  def todo_target_path_anchor(todo)
    dom_id(todo.note) if todo.note.present?
  end

  def todo_target_state_pill(todo)
    return unless show_todo_state?(todo)

    type =
      case todo.target
      when MergeRequest
        'mr'
      when Issue
        'issue'
      end

    content_tag(:span, nil, class: 'target-status') do
      content_tag(:span, nil, class: "status-box status-box-#{type}-#{todo.target.state.dasherize}") do
        todo.target.state.capitalize
      end
    end
  end

  def todos_filter_params
    {
      state:      params[:state],
      project_id: params[:project_id],
      author_id:  params[:author_id],
      type:       params[:type],
      action_id:  params[:action_id]
    }
  end

  def todos_filter_empty?
    todos_filter_params.values.none?
  end

  def todos_filter_path(options = {})
    without = options.delete(:without)

    options = todos_filter_params.merge(options)

    if without.present?
      without.each do |key|
        options.delete(key)
      end
    end

    "#{request.path}?#{options.to_param}"
  end

  def todo_actions_options
    [
      { id: '', text: 'Any Action' },
      { id: Todo::ASSIGNED, text: 'Assigned' },
      { id: Todo::MENTIONED, text: 'Mentioned' },
      { id: Todo::MARKED, text: 'Added' },
      { id: Todo::BUILD_FAILED, text: 'Pipelines' },
      { id: Todo::DIRECTLY_ADDRESSED, text: 'Directly addressed' }
    ]
  end

  def todo_projects_options
    projects = current_user.authorized_projects.sorted_by_activity.non_archived.with_route

    projects = projects.map do |project|
      { id: project.id, text: project.full_name }
    end

    projects.unshift({ id: '', text: 'Any Project' }).to_json
  end

  def todo_types_options
    [
      { id: '', text: 'Any Type' },
      { id: 'Issue', text: 'Issue' },
      { id: 'MergeRequest', text: 'Merge Request' }
    ]
  end

  def todo_actions_dropdown_label(selected_action_id, default_action)
    selected_action = todo_actions_options.find { |action| action[:id] == selected_action_id.to_i}
    selected_action ? selected_action[:text] : default_action
  end

  def todo_types_dropdown_label(selected_type, default_type)
    selected_type = todo_types_options.find { |type| type[:id] == selected_type && type[:id] != '' }
    selected_type ? selected_type[:text] : default_type
  end

  def todo_due_date(todo)
    return unless todo.target.try(:due_date)

    is_due_today = todo.target.due_date.today?
    is_overdue = todo.target.overdue?
    css_class =
      if is_due_today
        'text-warning'
      elsif is_overdue
        'text-danger'
      else
        ''
      end

    content = content_tag(:span, class: css_class) do
      "Due #{is_due_today ? "today" : todo.target.due_date.to_s(:medium)}"
    end

    "&middot; #{content}".html_safe
  end

  private

  def todo_action_subject(todo)
    todo.self_added? ? 'yourself' : 'you'
  end

  def show_todo_state?(todo)
    (todo.target.is_a?(MergeRequest) || todo.target.is_a?(Issue)) && %w(closed merged).include?(todo.target.state)
  end

  def todo_group_options
    groups = current_user.authorized_groups.with_route.map do |group|
      { id: group.id, text: group.full_name }
    end

    groups.unshift({ id: '', text: 'Any Group' }).to_json
  end
end

TodosHelper.prepend_if_ee('EE::NotesHelper'); TodosHelper.prepend_if_ee('EE::TodosHelper') # rubocop: disable Style/Semicolon
