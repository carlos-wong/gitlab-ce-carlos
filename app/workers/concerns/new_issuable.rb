# frozen_string_literal: true

module NewIssuable
  attr_reader :issuable, :user

  def objects_found?(issuable_id, user_id)
    set_user(user_id)
    set_issuable(issuable_id)

    user && issuable
  end

  # rubocop: disable CodeReuse/ActiveRecord
  def set_user(user_id)
    @user = User.find_by(id: user_id) # rubocop:disable Gitlab/ModuleWithInstanceVariables

    log_error(User, user_id) unless @user # rubocop:disable Gitlab/ModuleWithInstanceVariables
  end
  # rubocop: enable CodeReuse/ActiveRecord

  # rubocop: disable CodeReuse/ActiveRecord
  def set_issuable(issuable_id)
    @issuable = issuable_class.find_by(id: issuable_id) # rubocop:disable Gitlab/ModuleWithInstanceVariables

    log_error(issuable_class, issuable_id) unless @issuable # rubocop:disable Gitlab/ModuleWithInstanceVariables
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def log_error(record_class, record_id)
    Rails.logger.error("#{self.class}: couldn't find #{record_class} with ID=#{record_id}, skipping job") # rubocop:disable Gitlab/RailsLogger
  end
end
