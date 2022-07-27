# frozen_string_literal: true

module SortingHelper
  include SortingTitlesValuesHelper

  # rubocop: disable Metrics/AbcSize
  def sort_options_hash
    {
      sort_value_created_date      => sort_title_created_date,
      sort_value_downvotes         => sort_title_downvotes,
      sort_value_due_date          => sort_title_due_date,
      sort_value_due_date_later    => sort_title_due_date_later,
      sort_value_due_date_soon     => sort_title_due_date_soon,
      sort_value_label_priority    => sort_title_label_priority,
      sort_value_largest_group     => sort_title_largest_group,
      sort_value_largest_repo      => sort_title_largest_repo,
      sort_value_milestone         => sort_title_milestone,
      sort_value_milestone_later   => sort_title_milestone_later,
      sort_value_milestone_soon    => sort_title_milestone_soon,
      sort_value_name              => sort_title_name,
      sort_value_name_desc         => sort_title_name_desc,
      sort_value_oldest_created    => sort_title_oldest_created,
      sort_value_oldest_signin     => sort_title_oldest_signin,
      sort_value_oldest_updated    => sort_title_oldest_updated,
      sort_value_recently_created  => sort_title_recently_created,
      sort_value_recently_signin   => sort_title_recently_signin,
      sort_value_recently_updated  => sort_title_recently_updated,
      sort_value_popularity        => sort_title_popularity,
      sort_value_priority          => sort_title_priority,
      sort_value_merged_date       => sort_title_merged_date,
      sort_value_merged_recently   => sort_title_merged_recently,
      sort_value_merged_earlier    => sort_title_merged_earlier,
      sort_value_closed_date       => sort_title_closed_date,
      sort_value_closed_recently   => sort_title_closed_recently,
      sort_value_closed_earlier    => sort_title_closed_earlier,
      sort_value_upvotes           => sort_title_upvotes,
      sort_value_contacted_date    => sort_title_contacted_date,
      sort_value_relative_position => sort_title_relative_position,
      sort_value_size              => sort_title_size,
      sort_value_expire_date       => sort_title_expire_date,
      sort_value_title             => sort_title_title
    }
  end
  # rubocop: enable Metrics/AbcSize

  def projects_sort_options_hash
    use_old_sorting = Feature.disabled?(:project_list_filter_bar) || current_controller?('admin/projects')

    options = {
      sort_value_latest_activity  => sort_title_latest_activity,
      sort_value_recently_created => sort_title_created_date,
      sort_value_name             => sort_title_name,
      sort_value_name_desc        => sort_title_name_desc,
      sort_value_stars_desc       => sort_title_stars
    }

    if use_old_sorting
      options = options.merge({
        sort_value_oldest_activity  => sort_title_oldest_activity,
        sort_value_oldest_created   => sort_title_oldest_created,
        sort_value_recently_created => sort_title_recently_created,
        sort_value_stars_desc       => sort_title_most_stars
      })
    end

    if current_controller?('admin/projects')
      options[sort_value_largest_repo] = sort_title_largest_repo
    end

    options
  end

  def forks_sort_options_hash
    {
      sort_value_recently_created => sort_title_created_date,
      sort_value_oldest_created   => sort_title_created_date,
      sort_value_latest_activity  => sort_title_latest_activity,
      sort_value_oldest_activity  => sort_title_latest_activity
    }
  end

  def projects_sort_option_titles
    # Only used for the project filter search bar
    projects_sort_options_hash.merge({
      sort_value_oldest_activity  => sort_title_latest_activity,
      sort_value_oldest_created   => sort_title_created_date,
      sort_value_name_desc        => sort_title_name,
      sort_value_stars_asc        => sort_title_stars
    })
  end

  def projects_reverse_sort_options_hash
    {
      sort_value_latest_activity  => sort_value_oldest_activity,
      sort_value_recently_created => sort_value_oldest_created,
      sort_value_name             => sort_value_name_desc,
      sort_value_stars_desc       => sort_value_stars_asc,
      sort_value_oldest_activity  => sort_value_latest_activity,
      sort_value_oldest_created   => sort_value_recently_created,
      sort_value_name_desc        => sort_value_name,
      sort_value_stars_asc        => sort_value_stars_desc
    }
  end

  def forks_reverse_sort_options_hash
    {
      sort_value_recently_created => sort_value_oldest_created,
      sort_value_oldest_created   => sort_value_recently_created,
      sort_value_latest_activity  => sort_value_oldest_activity,
      sort_value_oldest_activity  => sort_value_latest_activity
    }
  end

  def groups_sort_options_hash
    {
      sort_value_name             => sort_title_name,
      sort_value_name_desc        => sort_title_name_desc,
      sort_value_recently_created => sort_title_recently_created,
      sort_value_oldest_created   => sort_title_oldest_created,
      sort_value_latest_activity  => sort_title_recently_updated,
      sort_value_oldest_activity  => sort_title_oldest_updated
    }
  end

  def subgroups_sort_options_hash
    groups_sort_options_hash.merge(
      sort_value_stars_desc => sort_title_most_stars
    )
  end

  def admin_groups_sort_options_hash
    groups_sort_options_hash.merge(
      sort_value_largest_group => sort_title_largest_group
    )
  end

  def milestones_sort_options_hash
    {
      sort_value_due_date_soon    => sort_title_due_date_soon,
      sort_value_due_date_later   => sort_title_due_date_later,
      sort_value_start_date_soon  => sort_title_start_date_soon,
      sort_value_start_date_later => sort_title_start_date_later,
      sort_value_name             => sort_title_name_asc,
      sort_value_name_desc        => sort_title_name_desc
    }
  end

  def branches_sort_options_hash
    {
      sort_value_name             => sort_title_name,
      sort_value_oldest_updated   => sort_title_oldest_updated,
      sort_value_recently_updated => sort_title_recently_updated
    }
  end

  def tags_sort_options_hash
    {
      sort_value_name             => sort_title_name,
      sort_value_oldest_updated   => sort_title_oldest_updated,
      sort_value_recently_updated => sort_title_recently_updated
    }
  end

  def label_sort_options_hash
    {
      sort_value_name => sort_title_name,
      sort_value_name_desc => sort_title_name_desc,
      sort_value_recently_created => sort_title_recently_created,
      sort_value_oldest_created => sort_title_oldest_created,
      sort_value_recently_updated => sort_title_recently_updated,
      sort_value_oldest_updated => sort_title_oldest_updated
    }
  end

  def users_sort_options_hash
    {
      sort_value_name => sort_title_name,
      sort_value_recently_signin => sort_title_recently_signin,
      sort_value_oldest_signin => sort_title_oldest_signin,
      sort_value_recently_created => sort_title_recently_created,
      sort_value_oldest_created => sort_title_oldest_created,
      sort_value_recently_updated => sort_title_recently_updated,
      sort_value_oldest_updated => sort_title_oldest_updated,
      sort_value_recently_last_activity => sort_title_recently_last_activity,
      sort_value_oldest_last_activity => sort_title_oldest_last_activity
    }
  end

  def runners_sort_options_hash
    {
      sort_value_created_date => sort_title_created_date,
      sort_value_contacted_date => sort_title_contacted_date
    }
  end

  def starrers_sort_options_hash
    {
      sort_value_name => sort_title_name,
      sort_value_name_desc => sort_title_name_desc,
      sort_value_recently_created => sort_title_recently_starred,
      sort_value_oldest_created => sort_title_oldest_starred
    }
  end

  def sortable_item(item, path, sorted_by)
    link_to item, path, class: sorted_by == item ? 'is-active' : ''
  end

  def issuable_sort_option_overrides
    {
      sort_value_oldest_created => sort_value_created_date,
      sort_value_oldest_updated => sort_value_recently_updated,
      sort_value_milestone_later => sort_value_milestone,
      sort_value_due_date_later => sort_value_due_date,
      sort_value_merged_recently => sort_value_merged_date,
      sort_value_closed_recently => sort_value_closed_date,
      sort_value_least_popular => sort_value_popularity,
      sort_value_title_desc => sort_value_title
    }
  end

  def issuable_reverse_sort_order_hash
    {
      sort_value_created_date => sort_value_oldest_created,
      sort_value_recently_created => sort_value_oldest_created,
      sort_value_recently_updated => sort_value_oldest_updated,
      sort_value_milestone => sort_value_milestone_later,
      sort_value_due_date => sort_value_due_date_later,
      sort_value_due_date_soon => sort_value_due_date_later,
      sort_value_merged_date => sort_value_merged_recently,
      sort_value_merged_earlier => sort_value_merged_recently,
      sort_value_closed_date => sort_value_closed_recently,
      sort_value_closed_earlier => sort_value_closed_recently,
      sort_value_popularity => sort_value_least_popular,
      sort_value_most_popular => sort_value_least_popular,
      sort_value_title => sort_value_title_desc
    }.merge(issuable_sort_option_overrides)
  end

  def audit_logs_sort_order_hash
    {
      sort_value_recently_created => sort_title_recently_created,
      sort_value_oldest_created   => sort_title_oldest_created
    }
  end

  def issuable_sort_option_title(sort_value)
    sort_value = issuable_sort_option_overrides[sort_value] || sort_value

    sort_options_hash[sort_value]
  end

  def issuable_sort_options(viewing_issues, viewing_merge_requests)
    options = [
      { value: sort_value_priority, text: sort_title_priority, href: page_filter_path(sort: sort_value_priority) },
      { value: sort_value_created_date, text: sort_title_created_date, href: page_filter_path(sort: sort_value_created_date) },
      { value: sort_value_closed_date, text: sort_title_closed_date, href: page_filter_path(sort: sort_value_closed_date) },
      { value: sort_value_recently_updated, text: sort_title_recently_updated, href: page_filter_path(sort: sort_value_recently_updated) },
      { value: sort_value_milestone, text: sort_title_milestone, href: page_filter_path(sort: sort_value_milestone) }
    ]

    options.concat([due_date_option]) if viewing_issues

    options.concat([popularity_option, label_priority_option])
    options.concat([merged_option]) if viewing_merge_requests
    options.concat([relative_position_option]) if viewing_issues

    options.concat([title_option])
  end

  def can_sort_by_issue_weight?(_viewing_issues)
    false
  end

  def due_date_option
    { value: sort_value_due_date, text: sort_title_due_date, href: page_filter_path(sort: sort_value_due_date) }
  end

  def popularity_option
    { value: sort_value_popularity, text: sort_title_popularity, href: page_filter_path(sort: sort_value_popularity) }
  end

  def label_priority_option
    { value: sort_value_label_priority, text: sort_title_label_priority, href: page_filter_path(sort: sort_value_label_priority) }
  end

  def merged_option
    { value: sort_value_merged_date, text: sort_title_merged_date, href: page_filter_path(sort: sort_value_merged_date) }
  end

  def relative_position_option
    { value: sort_value_relative_position, text: sort_title_relative_position, href: page_filter_path(sort: sort_value_relative_position) }
  end

  def title_option
    { value: sort_value_title, text: sort_title_title, href: page_filter_path(sort: sort_value_title) }
  end

  def sort_direction_icon(sort_value)
    case sort_value
    when sort_value_milestone, sort_value_due_date, sort_value_merged_date, sort_value_closed_date, /_asc\z/
      'sort-lowest'
    else
      'sort-highest'
    end
  end

  def sort_direction_button(reverse_url, reverse_sort, sort_value)
    link_class = 'gl-button btn btn-default btn-icon has-tooltip reverse-sort-btn qa-reverse-sort rspec-reverse-sort'
    icon = sort_direction_icon(sort_value)
    url = reverse_url

    unless reverse_sort
      url = '#'
      link_class += ' disabled'
    end

    link_to(url, type: 'button', class: link_class, title: s_('SortOptions|Sort direction')) do
      sprite_icon(icon)
    end
  end

  def issuable_sort_direction_button(sort_value)
    reverse_sort = issuable_reverse_sort_order_hash[sort_value]
    url = page_filter_path(sort: reverse_sort)

    sort_direction_button(url, reverse_sort, sort_value)
  end

  def project_sort_direction_button(sort_value)
    reverse_sort = projects_reverse_sort_options_hash[sort_value]
    url = filter_projects_path(sort: reverse_sort)

    sort_direction_button(url, reverse_sort, sort_value)
  end

  def packages_sort_options_hash
    {
      sort_value_recently_created  => sort_title_created_date,
      sort_value_oldest_created    => sort_title_created_date,
      sort_value_name              => sort_title_name,
      sort_value_name_desc         => sort_title_name,
      sort_value_version_desc      => sort_title_version,
      sort_value_version_asc       => sort_title_version,
      sort_value_type_desc         => sort_title_type,
      sort_value_type_asc          => sort_title_type,
      sort_value_project_name_desc => sort_title_project_name,
      sort_value_project_name_asc  => sort_title_project_name
    }
  end

  def packages_reverse_sort_order_hash
    {
      sort_value_recently_created  => sort_value_oldest_created,
      sort_value_oldest_created    => sort_value_recently_created,
      sort_value_name              => sort_value_name_desc,
      sort_value_name_desc         => sort_value_name,
      sort_value_version_desc      => sort_value_version_asc,
      sort_value_version_asc       => sort_value_version_desc,
      sort_value_type_desc         => sort_value_type_asc,
      sort_value_type_asc          => sort_value_type_desc,
      sort_value_project_name_desc => sort_value_project_name_asc,
      sort_value_project_name_asc  => sort_value_project_name_desc
    }
  end

  def packages_sort_option_title(sort_value)
    packages_sort_options_hash[sort_value] || sort_title_created_date
  end

  def packages_sort_direction_button(sort_value)
    reverse_sort = packages_reverse_sort_order_hash[sort_value]
    url = package_sort_path(sort: reverse_sort)

    sort_direction_button(url, reverse_sort, sort_value)
  end

  def forks_sort_direction_button(sort_value, without = [:state, :scope, :label_name, :milestone_id, :assignee_id, :author_id])
    reverse_sort = forks_reverse_sort_options_hash[sort_value]
    url = page_filter_path(sort: reverse_sort, without: without)

    sort_direction_button(url, reverse_sort, sort_value)
  end

  def admin_users_sort_options(path_params)
    users_sort_options_hash.map do |value, text|
      {
        value: value,
        text: text,
        href: admin_users_path(sort: value, **path_params)
      }
    end
  end
end

SortingHelper.prepend_mod_with('SortingHelper')
