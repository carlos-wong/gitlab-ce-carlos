# frozen_string_literal: true

module ExportHelper
  # An EE-overwriteable list of descriptions
  def project_export_descriptions
    [
      _('Project and wiki repositories'),
      _('Project uploads'),
      _('Project configuration, including services'),
      _('Issues with comments, merge requests with diffs and comments, labels, milestones, snippets, and other project entities'),
      _('LFS objects'),
      _('Issue Boards')
    ]
  end
end

ExportHelper.prepend_if_ee('EE::ExportHelper')
