# frozen_string_literal: true

# The RebaseWorker must be wrapped in important concurrency code, so should only
# be scheduled via MergeRequest#rebase_async
class RebaseWorker # rubocop:disable Scalability/IdempotentWorker
  include ApplicationWorker

  feature_category :source_code_management
  weight 2

  def perform(merge_request_id, current_user_id, skip_ci = false)
    current_user = User.find(current_user_id)
    merge_request = MergeRequest.find(merge_request_id)

    MergeRequests::RebaseService
      .new(merge_request.source_project, current_user)
      .execute(merge_request, skip_ci: skip_ci)
  end
end
