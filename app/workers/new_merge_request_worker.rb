# frozen_string_literal: true

class NewMergeRequestWorker
  include ApplicationWorker
  include NewIssuable

  feature_category :source_code_management

  def perform(merge_request_id, user_id)
    return unless objects_found?(merge_request_id, user_id)

    EventCreateService.new.open_mr(issuable, user)
    NotificationService.new.new_merge_request(issuable, user)

    issuable.diffs(include_stats: false).write_cache
    issuable.create_cross_references!(user)
  end

  def issuable_class
    MergeRequest
  end
end
