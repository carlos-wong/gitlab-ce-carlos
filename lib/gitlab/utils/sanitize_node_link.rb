# frozen_string_literal: true

require_dependency 'gitlab/utils'

module Gitlab
  module Utils
    module SanitizeNodeLink
      UNSAFE_PROTOCOLS  = %w(data javascript vbscript).freeze
      ATTRS_TO_SANITIZE = %w(href src data-src).freeze

      def remove_unsafe_links(env, remove_invalid_links: true)
        node = env[:node]

        sanitize_node(node: node, remove_invalid_links: remove_invalid_links)

        # HTML entities such as <video></video> have scannable attrs in
        #   children elements, which also need to be sanitized.
        #
        node.children.each do |child_node|
          sanitize_node(node: child_node, remove_invalid_links: remove_invalid_links)
        end
      end

      # Remove all invalid scheme characters before checking against the
      # list of unsafe protocols.
      #
      # See https://tools.ietf.org/html/rfc3986#section-3.1
      #
      def safe_protocol?(scheme)
        return false unless scheme

        scheme = scheme
          .strip
          .downcase
          .gsub(/[^A-Za-z\+\.\-]+/, '')

        UNSAFE_PROTOCOLS.none?(scheme)
      end

      private

      def sanitize_node(node:, remove_invalid_links: true)
        ATTRS_TO_SANITIZE.each do |attr|
          next unless node.has_attribute?(attr)

          begin
            node[attr] = node[attr].strip
            uri = Addressable::URI.parse(node[attr])

            next unless uri.scheme
            next if safe_protocol?(uri.scheme)

            node.remove_attribute(attr)
          rescue Addressable::URI::InvalidURIError
            node.remove_attribute(attr) if remove_invalid_links
          end
        end
      end
    end
  end
end
