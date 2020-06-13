# frozen_string_literal: true

module Gitlab
  module IncomingEmail
    UNSUBSCRIBE_SUFFIX        = '-unsubscribe'
    UNSUBSCRIBE_SUFFIX_LEGACY = '+unsubscribe'
    WILDCARD_PLACEHOLDER      = '%{key}'

    class << self
      def enabled?
        config.enabled && config.address
      end

      def supports_wildcard?
        config.address && config.address.include?(WILDCARD_PLACEHOLDER)
      end

      def supports_issue_creation?
        enabled? && supports_wildcard?
      end

      def reply_address(key)
        config.address.sub(WILDCARD_PLACEHOLDER, key)
      end

      # example: incoming+1234567890abcdef1234567890abcdef-unsubscribe@incoming.gitlab.com
      def unsubscribe_address(key)
        config.address.sub(WILDCARD_PLACEHOLDER, "#{key}#{UNSUBSCRIBE_SUFFIX}")
      end

      def key_from_address(address, wildcard_address: nil)
        wildcard_address ||= config.address
        regex = address_regex(wildcard_address)
        return unless regex

        match = address.match(regex)
        return unless match

        match[1]
      end

      def key_from_fallback_message_id(mail_id)
        message_id_regexp = /\Areply\-(.+)@#{Gitlab.config.gitlab.host}\z/

        mail_id[message_id_regexp, 1]
      end

      def scan_fallback_references(references)
        # It's looking for each <...>
        references.scan(/(?!<)[^<>]+(?=>)/)
      end

      def config
        Gitlab.config.incoming_email
      end

      private

      def address_regex(wildcard_address)
        return unless wildcard_address

        regex = Regexp.escape(wildcard_address)
        regex = regex.sub(Regexp.escape(WILDCARD_PLACEHOLDER), '(.+)')
        Regexp.new(/\A<?#{regex}>?\z/).freeze
      end
    end
  end
end
