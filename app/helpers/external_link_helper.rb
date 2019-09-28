# frozen_string_literal: true

module ExternalLinkHelper
  def external_link(body, url, options = {})
    link_to url, { target: '_blank', rel: 'noopener noreferrer' }.merge(options) do
      "#{body} #{icon('external-link')}".html_safe
    end
  end
end
