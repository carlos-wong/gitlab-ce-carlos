# frozen_string_literal: true

class ResourceMilestoneEvent < ResourceEvent
  belongs_to :issue
  belongs_to :merge_request
  belongs_to :milestone

  scope :by_issue, ->(issue) { where(issue_id: issue.id) }
  scope :by_merge_request, ->(merge_request) { where(merge_request_id: merge_request.id) }

  validate :exactly_one_issuable

  enum action: {
         add: 1,
         remove: 2
       }

  # state is used for issue and merge request states.
  enum state: Issue.available_states.merge(MergeRequest.available_states)

  def self.issuable_attrs
    %i(issue merge_request).freeze
  end
end
