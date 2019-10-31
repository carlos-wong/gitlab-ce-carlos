# frozen_string_literal: true

class DeleteUserWorker
  include ApplicationWorker

  feature_category :authentication_and_authorization

  def perform(current_user_id, delete_user_id, options = {})
    delete_user  = User.find(delete_user_id)
    current_user = User.find(current_user_id)

    Users::DestroyService.new(current_user).execute(delete_user, options.symbolize_keys)
  rescue Gitlab::Access::AccessDeniedError => e
    Rails.logger.warn("User could not be destroyed: #{e}") # rubocop:disable Gitlab/RailsLogger
  end
end
