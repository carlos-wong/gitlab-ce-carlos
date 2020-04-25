# frozen_string_literal: true

class UserProjectAccessChangedService
  def initialize(user_ids)
    @user_ids = Array.wrap(user_ids)
  end

  def execute(blocking: true)
    bulk_args = @user_ids.map { |id| [id] }

    if blocking
      AuthorizedProjectsWorker.bulk_perform_and_wait(bulk_args)
    else
      AuthorizedProjectsWorker.bulk_perform_async(bulk_args) # rubocop:disable Scalability/BulkPerformWithContext
    end
  end
end

UserProjectAccessChangedService.prepend_if_ee('EE::UserProjectAccessChangedService')
