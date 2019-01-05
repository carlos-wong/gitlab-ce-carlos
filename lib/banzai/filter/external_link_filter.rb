# frozen_string_literal: true

module Banzai
  module Filter
    # HTML Filter to modify the attributes of external links
    class ExternalLinkFilter < HTML::Pipeline::Filter
      SCHEMES = ['http', 'https', nil].freeze

      def call
        links.each do |node|
          uri = uri(node['href'].to_s)

          node.set_attribute('href', uri.to_s) if uri

          if SCHEMES.include?(uri&.scheme) && !internal_url?(uri)
            node.set_attribute('rel', 'nofollow noreferrer noopener')
            node.set_attribute('target', '_blank')
          end
        end

        doc
      end

      private

      def uri(href)
        URI.parse(href)
      rescue URI::Error
        nil
      end

      def links
        query = 'descendant-or-self::a[@href and not(@href = "")]'
        doc.xpath(query)
      end

      def internal_url?(uri)
        return false if uri.nil?
        # Relative URLs miss a hostname
        return true unless uri.hostname

        uri.hostname == internal_url.hostname
      end

      def internal_url
        @internal_url ||= URI.parse(Gitlab.config.gitlab.url)
      end
    end
  end
end
