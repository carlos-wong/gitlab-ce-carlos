# frozen_string_literal: true

module LabelsHelper
  extend self

  def show_label_issuables_link?(label, issuables_type, current_user: nil)
    return true unless label.project_label?

    label.project.feature_available?(issuables_type, current_user)
  end

  # Link to a Label
  #
  # label   - LabelPresenter object to link to
  # type    - The type of item the link will point to (:issue or
  #           :merge_request). If omitted, defaults to :issue.
  # block   - An optional block that will be passed to `link_to`, forming the
  #           body of the link element. If omitted, defaults to
  #           `render_colored_label`.
  #
  # Examples:
  #
  #   # Allow the generated link to use the label's own subject
  #   link_to_label(label)
  #
  #   # Force the generated link to use a provided group
  #   link_to_label(label, subject: Group.last)
  #
  #   # Force the generated link to use a provided project
  #   link_to_label(label, subject: Project.last)
  #
  #   # Force the generated link to point to merge requests instead of issues
  #   link_to_label(label, type: :merge_request)
  #
  #   # Customize link body with a block
  #   link_to_label(label) { "My Custom Label Text" }
  #
  # Returns a String
  def link_to_label(label, type: :issue, tooltip: true, small: false, &block)
    link = label.filter_path(type: type)

    if block_given?
      link_to link, &block
    else
      render_label(label, link: link, tooltip: tooltip, small: small)
    end
  end

  def render_label(label, link: nil, tooltip: true, dataset: nil, small: false)
    html = render_colored_label(label)

    if link
      title = label_tooltip_title(label) if tooltip
      html = render_label_link(html, link: link, title: title, dataset: dataset)
    end

    wrap_label_html(html, small: small, label: label)
  end

  def render_colored_label(label, suffix: '')
    render_label_text(
      label.name,
      suffix: suffix,
      css_class: text_color_class_for_bg(label.color),
      bg_color: label.color
    )
  end

  # We need the `label` argument here for EE
  def wrap_label_html(label_html, small:, label:)
    wrapper_classes = %w(gl-label)
    wrapper_classes << 'gl-label-sm' if small

    %(<span class="#{wrapper_classes.join(' ')}">#{label_html}</span>).html_safe
  end

  def label_tooltip_title(label)
    Sanitize.clean(label.description)
  end

  def suggested_colors
    {
      '#0033CC' => s_('SuggestedColors|UA blue'),
      '#428BCA' => s_('SuggestedColors|Moderate blue'),
      '#44AD8E' => s_('SuggestedColors|Lime green'),
      '#A8D695' => s_('SuggestedColors|Feijoa'),
      '#5CB85C' => s_('SuggestedColors|Slightly desaturated green'),
      '#69D100' => s_('SuggestedColors|Bright green'),
      '#004E00' => s_('SuggestedColors|Very dark lime green'),
      '#34495E' => s_('SuggestedColors|Very dark desaturated blue'),
      '#7F8C8D' => s_('SuggestedColors|Dark grayish cyan'),
      '#A295D6' => s_('SuggestedColors|Slightly desaturated blue'),
      '#5843AD' => s_('SuggestedColors|Dark moderate blue'),
      '#8E44AD' => s_('SuggestedColors|Dark moderate violet'),
      '#FFECDB' => s_('SuggestedColors|Very pale orange'),
      '#AD4363' => s_('SuggestedColors|Dark moderate pink'),
      '#D10069' => s_('SuggestedColors|Strong pink'),
      '#CC0033' => s_('SuggestedColors|Strong red'),
      '#FF0000' => s_('SuggestedColors|Pure red'),
      '#D9534F' => s_('SuggestedColors|Soft red'),
      '#D1D100' => s_('SuggestedColors|Strong yellow'),
      '#F0AD4E' => s_('SuggestedColors|Soft orange'),
      '#AD8D43' => s_('SuggestedColors|Dark moderate orange')
    }
  end

  def render_suggested_colors
    colors_html = suggested_colors.map do |color_hex_value, color_name|
      link_to('', '#', class: "has-tooltip", style: "background-color: #{color_hex_value}", data: { color: color_hex_value }, title: color_name)
    end

    content_tag(:div, class: 'suggest-colors') do
      colors_html.join.html_safe
    end
  end

  def text_color_class_for_bg(bg_color)
    if light_color?(bg_color)
      'gl-label-text-dark'
    else
      'gl-label-text-light'
    end
  end

  def text_color_for_bg(bg_color)
    if light_color?(bg_color)
      '#333333'
    else
      '#FFFFFF'
    end
  end

  def light_color?(color)
    if color.length == 4
      r, g, b = color[1, 4].scan(/./).map { |v| (v * 2).hex }
    else
      r, g, b = color[1, 7].scan(/.{2}/).map(&:hex)
    end

    (r + g + b) > 500
  end

  def labels_filter_path_with_defaults(only_group_labels: false, include_ancestor_groups: true, include_descendant_groups: false)
    options = {}
    options[:include_ancestor_groups] = include_ancestor_groups if include_ancestor_groups
    options[:include_descendant_groups] = include_descendant_groups if include_descendant_groups
    options[:only_group_labels] = only_group_labels if only_group_labels && @group
    options[:format] = :json

    labels_filter_path(options)
  end

  def labels_filter_path(options = {})
    project = @target_project || @project
    format = options.delete(:format)

    if project
      project_labels_path(project, format, options)
    elsif @group
      group_labels_path(@group, format, options)
    else
      dashboard_labels_path(format, options)
    end
  end

  def label_subscription_status(label, project)
    return 'group-level' if label.subscribed?(current_user)
    return 'project-level' if label.subscribed?(current_user, project)

    'unsubscribed'
  end

  def toggle_subscription_label_path(label, project)
    return toggle_subscription_group_label_path(label.group, label) unless project

    case label_subscription_status(label, project)
    when 'group-level' then toggle_subscription_group_label_path(label.group, label)
    when 'project-level' then toggle_subscription_project_label_path(project, label)
    when 'unsubscribed' then toggle_subscription_project_label_path(project, label)
    end
  end

  def label_subscription_toggle_button_text(label, project = nil)
    label.subscribed?(current_user, project) ? 'Unsubscribe' : 'Subscribe'
  end

  def create_label_title(subject)
    case subject
    when Group
      _('Create group label')
    when Project
      _('Create project label')
    else
      _('Create new label')
    end
  end

  def manage_labels_title(subject)
    case subject
    when Group
      _('Manage group labels')
    when Project
      _('Manage project labels')
    else
      _('Manage labels')
    end
  end

  def view_labels_title(subject)
    case subject
    when Group
      _('View group labels')
    when Project
      _('View project labels')
    else
      _('View labels')
    end
  end

  def label_status_tooltip(label, status)
    type = label.project_label? ? 'project' : 'group'
    level = status.unsubscribed? ? type : status.sub('-level', '')
    action = status.unsubscribed? ? 'Subscribe' : 'Unsubscribe'

    "#{action} at #{level} level"
  end

  def presented_labels_sorted_by_title(labels, subject)
    labels.sort_by(&:title).map { |label| label.present(issuable_subject: subject) }
  end

  def label_dropdown_data(project, opts = {})
    {
      toggle: "dropdown",
      field_name: opts[:field_name] || "label_name[]",
      show_no: "true",
      show_any: "true",
      project_id: project&.try(:id),
      namespace_path: project&.try(:namespace)&.try(:full_path),
      project_path: project&.try(:path)
    }.merge(opts)
  end

  def sidebar_label_dropdown_data(issuable_type, issuable_sidebar)
    label_dropdown_data(nil, {
     default_label: "Labels",
     field_name: "#{issuable_type}[label_names][]",
     ability_name: issuable_type,
     namespace_path: issuable_sidebar[:namespace_path],
     project_path: issuable_sidebar[:project_path],
     issue_update: issuable_sidebar[:issuable_json_path],
     labels: issuable_sidebar[:project_labels_path],
     display: 'static'
    })
  end

  def label_from_hash(hash)
    klass = hash[:group_id] ? GroupLabel : ProjectLabel

    klass.new(hash.slice(:color, :description, :title, :group_id, :project_id))
  end

  def issuable_types
    ['issues', 'merge requests']
  end

  private

  def render_label_link(label_html, link:, title:, dataset:)
    classes = %w(gl-link gl-label-link)
    dataset ||= {}

    if title.present?
      classes << 'has-tooltip'
      dataset.merge!(html: true, title: title)
    end

    link_to(label_html, link, class: classes.join(' '), data: dataset)
  end

  def render_label_text(name, suffix: '', css_class: nil, bg_color: nil)
    <<~HTML.chomp.html_safe
      <span
        class="gl-label-text #{css_class}"
        data-container="body"
        data-html="true"
        #{"style=\"background-color: #{bg_color}\"" if bg_color}
      >#{ERB::Util.html_escape_once(name)}#{suffix}</span>
    HTML
  end
end

LabelsHelper.prepend_if_ee('EE::LabelsHelper')
