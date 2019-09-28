# frozen_string_literal: true

# Base class for Chat services
# This class is not meant to be used directly, but only to inherrit from.
class SlashCommandsService < Service
  default_value_for :category, 'chat'

  prop_accessor :token

  has_many :chat_names, foreign_key: :service_id, dependent: :destroy # rubocop:disable Cop/ActiveRecordDependent

  def valid_token?(token)
    self.respond_to?(:token) &&
      self.token.present? &&
      ActiveSupport::SecurityUtils.secure_compare(token, self.token)
  end

  def self.supported_events
    %w()
  end

  def can_test?
    false
  end

  def fields
    [
      { type: 'text', name: 'token', placeholder: 'XXxxXXxxXXxxXXxxXXxxXXxx' }
    ]
  end

  def trigger(params)
    return unless valid_token?(params[:token])

    chat_user = find_chat_user(params)

    if chat_user&.user
      unless chat_user.user.can?(:use_slash_commands)
        return Gitlab::SlashCommands::Presenters::Access.new.access_denied(project)
      end

      Gitlab::SlashCommands::Command.new(project, chat_user, params).execute
    else
      url = authorize_chat_name_url(params)
      Gitlab::SlashCommands::Presenters::Access.new(url).authorize
    end
  end

  private

  # rubocop: disable CodeReuse/ServiceClass
  def find_chat_user(params)
    ChatNames::FindUserService.new(self, params).execute
  end
  # rubocop: enable CodeReuse/ServiceClass

  # rubocop: disable CodeReuse/ServiceClass
  def authorize_chat_name_url(params)
    ChatNames::AuthorizeUserService.new(self, params).execute
  end
  # rubocop: enable CodeReuse/ServiceClass
end
