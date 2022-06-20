# frozen_string_literal: true

module Banzai
  module Filter
    class CustomEmojiFilter < HTML::Pipeline::Filter
      include Gitlab::Utils::StrongMemoize

      IGNORED_ANCESTOR_TAGS = %w(pre code tt).to_set

      def call
        return doc unless resource_parent

        doc.xpath('descendant-or-self::text()').each do |node|
          content = node.to_html

          next if has_ancestor?(node, IGNORED_ANCESTOR_TAGS)
          next unless content.include?(':')
          next unless has_custom_emoji?

          html = custom_emoji_name_element_filter(content)

          node.replace(html) unless html == content
        end

        doc
      end

      def custom_emoji_pattern
        @emoji_pattern ||=
          /(?<=[^[:alnum:]:]|\n|^)
          :(#{CustomEmoji::NAME_REGEXP}):
          (?=[^[:alnum:]:]|$)/x
      end

      def custom_emoji_name_element_filter(text)
        text.gsub(custom_emoji_pattern) do |match|
          name = Regexp.last_match[1]
          custom_emoji = all_custom_emoji[name]

          if custom_emoji
            Gitlab::Emoji.custom_emoji_tag(custom_emoji.name, custom_emoji.url)
          else
            match
          end
        end
      end

      private

      def has_custom_emoji?
        strong_memoize(:has_custom_emoji) do
          CustomEmoji.for_resource(resource_parent).any?
        end
      end

      def resource_parent
        context[:project] || context[:group]
      end

      def custom_emoji_candidates
        doc.to_html.scan(/:(#{CustomEmoji::NAME_REGEXP}):/).flatten
      end

      def all_custom_emoji
        @all_custom_emoji ||=
          CustomEmoji.for_resource(resource_parent).by_name(custom_emoji_candidates).index_by(&:name)
      end
    end
  end
end
