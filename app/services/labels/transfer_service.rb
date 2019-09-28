# frozen_string_literal: true

# Labels::TransferService class
#
# User for recreate the missing group labels at project level
#
module Labels
  class TransferService
    def initialize(current_user, old_group, project)
      @current_user = current_user
      @old_group = old_group
      @project = project
    end

    def execute
      return unless old_group.present?

      Label.transaction do
        labels_to_transfer.find_each do |label|
          new_label_id = find_or_create_label!(label)

          next if new_label_id == label.id

          update_label_links(group_labels_applied_to_issues, old_label_id: label.id, new_label_id: new_label_id)
          update_label_links(group_labels_applied_to_merge_requests, old_label_id: label.id, new_label_id: new_label_id)
          update_label_priorities(old_label_id: label.id, new_label_id: new_label_id)
        end
      end
    end

    private

    attr_reader :current_user, :old_group, :project

    # rubocop: disable CodeReuse/ActiveRecord
    def labels_to_transfer
      Label
        .from_union([
          group_labels_applied_to_issues,
          group_labels_applied_to_merge_requests
        ])
        .reorder(nil)
        .distinct
    end
    # rubocop: enable CodeReuse/ActiveRecord

    # rubocop: disable CodeReuse/ActiveRecord
    def group_labels_applied_to_issues
      Label.joins(:issues)
        .where(
          issues: { project_id: project.id },
          labels: { type: 'GroupLabel', group_id: old_group.id }
        )
    end
    # rubocop: enable CodeReuse/ActiveRecord

    # rubocop: disable CodeReuse/ActiveRecord
    def group_labels_applied_to_merge_requests
      Label.joins(:merge_requests)
        .where(
          merge_requests: { target_project_id: project.id },
          labels: { type: 'GroupLabel', group_id: old_group.id }
        )
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def find_or_create_label!(label)
      params    = label.attributes.slice('title', 'description', 'color')
      new_label = FindOrCreateService.new(current_user, project, params).execute

      new_label.id
    end

    # rubocop: disable CodeReuse/ActiveRecord
    def update_label_links(labels, old_label_id:, new_label_id:)
      # use 'labels' relation to get label_link ids only of issues/MRs
      # in the project being transferred.
      # IDs are fetched in a separate query because MySQL doesn't
      # allow referring of 'label_links' table in UPDATE query:
      # https://gitlab.com/gitlab-org/gitlab-foss/-/jobs/62435068
      link_ids = labels.pluck('label_links.id')

      LabelLink.where(id: link_ids, label_id: old_label_id)
        .update_all(label_id: new_label_id)
    end
    # rubocop: enable CodeReuse/ActiveRecord

    # rubocop: disable CodeReuse/ActiveRecord
    def update_label_priorities(old_label_id:, new_label_id:)
      LabelPriority.where(project_id: project.id, label_id: old_label_id)
        .update_all(label_id: new_label_id)
    end
    # rubocop: enable CodeReuse/ActiveRecord
  end
end
