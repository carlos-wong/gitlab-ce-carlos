# frozen_string_literal: true

class AuthorizedProjectsWorker
  include ApplicationWorker
  prepend WaitableWorker

  feature_category :authentication_and_authorization
  latency_sensitive_worker!

  # This is a workaround for a Ruby 2.3.7 bug. rspec-mocks cannot restore the
  # visibility of prepended modules. See https://github.com/rspec/rspec-mocks/issues/1231
  # for more details.
  if Rails.env.test?
    def self.bulk_perform_and_wait(args_list, timeout: 10)
    end
  end

  # rubocop: disable CodeReuse/ActiveRecord
  def perform(user_id)
    user = User.find_by(id: user_id)

    user&.refresh_authorized_projects
  end
  # rubocop: enable CodeReuse/ActiveRecord
end
