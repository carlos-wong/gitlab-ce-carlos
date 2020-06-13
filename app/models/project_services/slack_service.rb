# frozen_string_literal: true

class SlackService < ChatNotificationService
  def title
    'Slack notifications'
  end

  def description
    'Receive event notifications in Slack'
  end

  def self.to_param
    'slack'
  end

  def default_channel_placeholder
    _('Slack channels (e.g. general, development)')
  end

  def webhook_placeholder
    'https://hooks.slack.com/services/…'
  end

  module Notifier
    private

    def notify(message, opts)
      # See https://gitlab.com/gitlab-org/slack-notifier/#custom-http-client
      notifier = Slack::Messenger.new(webhook, opts.merge(http_client: HTTPClient))

      notifier.ping(
        message.pretext,
        attachments: message.attachments,
        fallback: message.fallback
      )
    end

    class HTTPClient
      def self.post(uri, params = {})
        params.delete(:http_options) # these are internal to the client and we do not want them
        Gitlab::HTTP.post(uri, body: params)
      end
    end
  end

  include Notifier
end
