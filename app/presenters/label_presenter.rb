# frozen_string_literal: true

class LabelPresenter < Gitlab::View::Presenter::Delegated
  presents :label

  def edit_path
    case label
    when GroupLabel then edit_group_label_path(label.group, label)
    when ProjectLabel then edit_project_label_path(label.project, label)
    end
  end

  def destroy_path
    case label
    when GroupLabel then group_label_path(label.group, label)
    when ProjectLabel then project_label_path(label.project, label)
    end
  end

  def filter_path(type: :issue)
    case context_subject
    when Group
      send("#{type.to_s.pluralize}_group_path", # rubocop:disable GitlabSecurity/PublicSend
                  context_subject,
                  label_name: [label.name])
    when Project
      send("namespace_project_#{type.to_s.pluralize}_path", # rubocop:disable GitlabSecurity/PublicSend
                  context_subject.namespace,
                  context_subject,
                  label_name: [label.name])
    end
  end

  def can_subscribe_to_label_in_different_levels?
    issuable_subject.is_a?(Project) && label.is_a?(GroupLabel)
  end

  def project_label?
    label.is_a?(ProjectLabel)
  end

  def subject_name
    label.subject.name
  end

  private

  def context_subject
    issuable_subject || label.try(:subject)
  end
end
