# frozen_string_literal: true

module Integrations
  class UnifyCircuit < BaseChatNotification
    def title
      'Unify Circuit'
    end

    def description
      s_('Integrations|Send notifications about project events to Unify Circuit.')
    end

    def self.to_param
      'unify_circuit'
    end

    def help
      docs_link = ActionController::Base.helpers.link_to _('How do I set up this service?'), Rails.application.routes.url_helpers.help_page_url('user/project/integrations/unify_circuit'), target: '_blank', rel: 'noopener noreferrer'
      s_('Integrations|Send notifications about project events to a Unify Circuit conversation. %{docs_link}').html_safe % { docs_link: docs_link.html_safe }
    end

    def default_channel_placeholder
    end

    def self.supported_events
      %w[push issue confidential_issue merge_request note confidential_note tag_push
         pipeline wiki_page]
    end

    def default_fields
      [
        { type: 'text', name: 'webhook', placeholder: "https://yourcircuit.com/rest/v2/webhooks/incoming/…", required: true },
        { type: 'checkbox', name: 'notify_only_broken_pipelines' },
        {
          type: 'select',
          name: 'branches_to_be_notified',
          title: s_('Integrations|Branches for which notifications are to be sent'),
          choices: self.class.branch_choices
        }
      ]
    end

    private

    def notify(message, opts)
      response = Gitlab::HTTP.post(webhook, body: {
        subject: message.project_name,
        text: message.summary,
        markdown: true
      }.to_json)

      response if response.success?
    end

    def custom_data(data)
      super(data).merge(markdown: true)
    end
  end
end
