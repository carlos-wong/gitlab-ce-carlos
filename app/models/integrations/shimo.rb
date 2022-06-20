# frozen_string_literal: true

module Integrations
  class Shimo < BaseThirdPartyWiki
    prop_accessor :external_wiki_url
    validates :external_wiki_url, presence: true, public_url: true, if: :activated?

    def render?
      return false unless Feature.enabled?(:shimo_integration, project)

      valid? && activated?
    end

    def title
      s_('Shimo|Shimo')
    end

    def description
      s_('Shimo|Link to a Shimo Workspace from the sidebar.')
    end

    def self.to_param
      'shimo'
    end

    # support for `test` method
    def execute(_data)
      response = Gitlab::HTTP.get(properties['external_wiki_url'], verify: true, use_read_total_timeout: true)
      response.body if response.code == 200
    rescue StandardError
      nil
    end

    def fields
      [
        {
          type: 'text',
          name: 'external_wiki_url',
          title: s_('Shimo|Shimo Workspace URL'),
          required: true
        }
      ]
    end
  end
end
