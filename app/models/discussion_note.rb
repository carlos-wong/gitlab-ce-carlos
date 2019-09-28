# frozen_string_literal: true

# A note in a non-diff discussion on an issue, merge request, commit, or snippet.
#
# A note of this type can be resolvable.
class DiscussionNote < Note
  # This prepend must stay here because the `validates` below depends on it.
  prepend_if_ee('EE::DiscussionNote') # rubocop: disable Cop/InjectEnterpriseEditionModule

  # Names of all implementers of `Noteable` that support discussions.
  def self.noteable_types
    %w(MergeRequest Issue Commit Snippet)
  end

  validates :noteable_type, inclusion: { in: noteable_types }

  def discussion_class(*)
    Discussion
  end
end
