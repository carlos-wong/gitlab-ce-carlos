# frozen_string_literal: true

class MergeWorker
  include ApplicationWorker

  feature_category :source_code_management
  latency_sensitive_worker!
  weight 5

  def perform(merge_request_id, current_user_id, params)
    params = params.with_indifferent_access
    current_user = User.find(current_user_id)
    merge_request = MergeRequest.find(merge_request_id)

    MergeRequests::MergeService.new(merge_request.target_project, current_user, params)
      .execute(merge_request)
  end
end
