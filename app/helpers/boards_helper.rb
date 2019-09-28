# frozen_string_literal: true

module BoardsHelper
  def board
    @board ||= @board || @boards.first
  end

  def board_data
    {
      boards_endpoint: @boards_endpoint,
      lists_endpoint: board_lists_path(board),
      board_id: board.id,
      disabled: (!can?(current_user, :create_non_backlog_issues, board)).to_s,
      issue_link_base: build_issue_link_base,
      root_path: root_path,
      bulk_update_path: @bulk_issues_path,
      default_avatar: image_path(default_avatar),
      time_tracking_limit_to_hours: Gitlab::CurrentSettings.time_tracking_limit_to_hours.to_s,
      recent_boards_endpoint: recent_boards_path
    }
  end

  def build_issue_link_base
    if board.group_board?
      "#{group_path(@board.group)}/:project_path/issues"
    else
      project_issues_path(@project)
    end
  end

  def board_base_url
    if board.group_board?
      group_boards_url(@group)
    else
      project_boards_path(@project)
    end
  end

  def multiple_boards_available?
    current_board_parent.multiple_issue_boards_available?
  end

  def current_board_path(board)
    @current_board_path ||= if board.group_board?
                              group_board_path(current_board_parent, board)
                            else
                              project_board_path(current_board_parent, board)
                            end
  end

  def current_board_parent
    @current_board_parent ||= @group || @project
  end

  def can_admin_issue?
    can?(current_user, :admin_issue, current_board_parent)
  end

  def board_list_data
    include_descendant_groups = @group&.present?

    {
      toggle: "dropdown",
      list_labels_path: labels_filter_path_with_defaults(only_group_labels: true, include_ancestor_groups: true),
      labels: labels_filter_path_with_defaults(only_group_labels: true, include_descendant_groups: include_descendant_groups),
      labels_endpoint: @labels_endpoint,
      namespace_path: @namespace_path,
      project_path: @project&.path,
      group_path: @group&.path
    }
  end

  def board_sidebar_user_data
    dropdown_options = assignees_dropdown_options('issue')

    {
      toggle: 'dropdown',
      field_name: 'issue[assignee_ids][]',
      first_user: current_user&.username,
      current_user: 'true',
      project_id: @project&.id,
      group_id: @group&.id,
      null_user: 'true',
      multi_select: 'true',
      'dropdown-header': dropdown_options[:data][:'dropdown-header'],
      'max-select': dropdown_options[:data][:'max-select']
    }
  end

  def boards_link_text
    if current_board_parent.multiple_issue_boards_available?
      s_("IssueBoards|Boards")
    else
      s_("IssueBoards|Board")
    end
  end

  def recent_boards_path
    recent_project_boards_path(@project) if current_board_parent.is_a?(Project)
  end

  def serializer
    CurrentBoardSerializer.new
  end

  def current_board_json
    serializer.represent(board).as_json
  end
end

BoardsHelper.prepend_if_ee('EE::BoardsHelper')
