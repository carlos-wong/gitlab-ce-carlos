# frozen_string_literal: true

module IssuesHelper
  include Issues::IssueTypeHelpers

  def issue_css_classes(issue)
    classes = ["issue"]
    classes << "closed" if issue.closed?
    classes << "today" if issue.new?
    classes << "gl-cursor-grab" if @sort == 'relative_position'
    classes.join(' ')
  end

  def issue_manual_ordering_class
    is_sorting_by_relative_position = @sort == 'relative_position'

    if is_sorting_by_relative_position && !issue_repositioning_disabled?
      "manual-ordering"
    end
  end

  def issue_repositioning_disabled?
    if @group
      @group.root_ancestor.issue_repositioning_disabled?
    elsif @project
      @project.root_namespace.issue_repositioning_disabled?
    end
  end

  def status_box_class(item)
    if item.try(:expired?)
      'status-box-expired'
    elsif item.try(:merged?)
      'status-box-mr-merged'
    elsif item.closed?
      'status-box-mr-closed'
    elsif item.try(:upcoming?)
      'status-box-upcoming'
    else
      'status-box-open'
    end
  end

  def issue_status_visibility(issue, status_box:)
    case status_box
    when :open
      'hidden' if issue.closed?
    when :closed
      'hidden' unless issue.closed?
    end
  end

  def work_item_type_icon(issue_type)
    if WorkItems::Type.base_types.include?(issue_type)
      "issue-type-#{issue_type.to_s.dasherize}"
    else
      'issue-type-issue'
    end
  end

  def confidential_icon(issue)
    sprite_icon('eye-slash', css_class: 'gl-vertical-align-text-bottom') if issue.confidential?
  end

  def issue_hidden?(issue)
    Feature.enabled?(:ban_user_feature_flag, default_enabled: :yaml) && issue.hidden?
  end

  def hidden_issue_icon(issue)
    return unless issue_hidden?(issue)

    content_tag(:span, class: 'has-tooltip', title: _('This issue is hidden because its author has been banned')) do
      sprite_icon('spam', css_class: 'gl-vertical-align-text-bottom')
    end
  end

  def award_user_list(awards, current_user, limit: 10)
    names = awards.map do |award|
      award.user == current_user ? 'You' : award.user.name
    end

    current_user_name = names.delete('You')
    names = names.insert(0, current_user_name).compact.first(limit)

    names << "#{awards.size - names.size} more." if awards.size > names.size

    names.to_sentence
  end

  def award_state_class(awardable, awards, current_user)
    if !can?(current_user, :award_emoji, awardable)
      "disabled"
    elsif current_user && awards.find { |a| a.user_id == current_user.id }
      "selected"
    else
      ""
    end
  end

  def awards_sort(awards)
    awards.sort_by do |award, award_emojis|
      if award == "thumbsup"
        0
      elsif award == "thumbsdown"
        1
      else
        2
      end
    end.to_h
  end

  def link_to_discussions_to_resolve(merge_request, single_discussion = nil)
    link_text = [merge_request.to_reference]
    link_text << "(discussion #{single_discussion.first_note.id})" if single_discussion

    path = if single_discussion
             Gitlab::UrlBuilder.build(single_discussion.first_note)
           else
             project = merge_request.project
             project_merge_request_path(project, merge_request)
           end

    link_to link_text.join(' '), path
  end

  def show_new_issue_link?(project)
    return false unless project
    return false if project.archived?

    # We want to show the link to users that are not signed in, that way they
    # get directed to the sign-in/sign-up flow and afterwards to the new issue page.
    return true unless current_user

    can?(current_user, :create_issue, project)
  end

  def show_new_branch_button?
    can_create_confidential_merge_request? || !@issue.confidential?
  end

  def can_create_confidential_merge_request?
    @issue.confidential? && !@project.private? &&
      can?(current_user, :create_merge_request_in, @project)
  end

  def issue_closed_link(issue, current_user, css_class: '')
    if issue.moved? && can?(current_user, :read_issue, issue.moved_to)
      link_to(s_('IssuableStatus|moved'), issue.moved_to, class: css_class)
    elsif issue.duplicated? && can?(current_user, :read_issue, issue.duplicated_to)
      link_to(s_('IssuableStatus|duplicated'), issue.duplicated_to, class: css_class)
    end
  end

  def issue_closed_text(issue, current_user)
    link = issue_closed_link(issue, current_user, css_class: 'text-white text-underline')

    if link
      s_('IssuableStatus|Closed (%{link})').html_safe % { link: link }
    else
      s_('IssuableStatus|Closed')
    end
  end

  def show_moved_service_desk_issue_warning?(issue)
    return false unless issue.moved_from
    return false unless issue.from_service_desk?

    issue.moved_from.project.service_desk_enabled? && !issue.project.service_desk_enabled?
  end

  def issue_header_actions_data(project, issuable, current_user)
    new_issuable_params = { issue: {}, add_related_issue: issuable.iid }
    if issuable.incident?
      new_issuable_params[:issuable_template] = 'incident'
      new_issuable_params[:issue][:issue_type] = 'incident'
    end

    {
      can_create_issue: show_new_issue_link?(project).to_s,
      can_create_incident: create_issue_type_allowed?(project, :incident).to_s,
      can_destroy_issue: can?(current_user, :"destroy_#{issuable.to_ability_name}", issuable).to_s,
      can_reopen_issue: can?(current_user, :reopen_issue, issuable).to_s,
      can_report_spam: issuable.submittable_as_spam_by?(current_user).to_s,
      can_update_issue: can?(current_user, :update_issue, issuable).to_s,
      iid: issuable.iid,
      is_issue_author: (issuable.author == current_user).to_s,
      issue_path: issuable_path(issuable),
      issue_type: issuable_display_type(issuable),
      new_issue_path: new_project_issue_path(project, new_issuable_params),
      project_path: project.full_path,
      report_abuse_path: new_abuse_report_path(user_id: issuable.author.id, ref_url: issue_url(issuable)),
      submit_as_spam_path: mark_as_spam_project_issue_path(project, issuable)
    }
  end

  def common_issues_list_data(namespace, current_user)
    {
      autocomplete_award_emojis_path: autocomplete_award_emojis_path,
      calendar_path: url_for(safe_params.merge(calendar_url_options)),
      empty_state_svg_path: image_path('illustrations/issues.svg'),
      full_path: namespace.full_path,
      initial_sort: current_user&.user_preference&.issues_sort,
      is_anonymous_search_disabled: Feature.enabled?(:disable_anonymous_search, type: :ops).to_s,
      is_issue_repositioning_disabled: issue_repositioning_disabled?.to_s,
      is_signed_in: current_user.present?.to_s,
      jira_integration_path: help_page_url('integration/jira/issues', anchor: 'view-jira-issues'),
      rss_path: url_for(safe_params.merge(rss_url_options)),
      sign_in_path: new_user_session_path
    }
  end

  def project_issues_list_data(project, current_user)
    common_issues_list_data(project, current_user).merge(
      can_bulk_update: can?(current_user, :admin_issue, project).to_s,
      can_edit: can?(current_user, :admin_project, project).to_s,
      can_import_issues: can?(current_user, :import_issues, @project).to_s,
      email: current_user&.notification_email_or_default,
      emails_help_page_path: help_page_path('development/emails', anchor: 'email-namespace'),
      export_csv_path: export_csv_project_issues_path(project),
      has_any_issues: project_issues(project).exists?.to_s,
      import_csv_issues_path: import_csv_namespace_project_issues_path,
      initial_email: project.new_issuable_address(current_user, 'issue'),
      is_project: true.to_s,
      markdown_help_path: help_page_path('user/markdown'),
      max_attachment_size: number_to_human_size(Gitlab::CurrentSettings.max_attachment_size.megabytes),
      new_issue_path: new_project_issue_path(project),
      project_import_jira_path: project_import_jira_path(project),
      quick_actions_help_path: help_page_path('user/project/quick_actions'),
      releases_path: project_releases_path(project, format: :json),
      reset_path: new_issuable_address_project_path(project, issuable_type: 'issue'),
      show_new_issue_link: show_new_issue_link?(project).to_s
    )
  end

  def group_issues_list_data(group, current_user)
    common_issues_list_data(group, current_user).merge(
      has_any_issues: @has_issues.to_s,
      has_any_projects: @has_projects.to_s
    )
  end

  def issues_form_data(project)
    {
      new_issue_path: new_project_issue_path(project)
    }
  end

  # Overridden in EE
  def scoped_labels_available?(parent)
    false
  end

  def award_emoji_issue_api_path(issue)
    api_v4_projects_issues_award_emoji_path(id: issue.project.id, issue_iid: issue.iid)
  end
end

IssuesHelper.prepend_mod_with('IssuesHelper')
