# frozen_string_literal: true

module Banzai
  module Filter
    # Sanitize HTML produced by Markdown.
    #
    # Extends Banzai::Filter::BaseSanitizationFilter with specific rules.
    class SanitizationFilter < Banzai::Filter::BaseSanitizationFilter
      # Styles used by Markdown for table alignment
      TABLE_ALIGNMENT_PATTERN = /text-align: (?<alignment>center|left|right)/.freeze

      def customize_whitelist(whitelist)
        # Allow table alignment; we whitelist specific text-align values in a
        # transformer below
        whitelist[:attributes]['th'] = %w(style)
        whitelist[:attributes]['td'] = %w(style)
        whitelist[:css] = { properties: ['text-align'] }

        # Allow the 'data-sourcepos' from CommonMark on all elements
        whitelist[:attributes][:all].push('data-sourcepos')

        # Remove any `style` properties not required for table alignment
        whitelist[:transformers].push(self.class.remove_unsafe_table_style)

        # Allow `id` in a and li elements for footnotes
        # and remove any `id` properties not matching for footnotes
        whitelist[:attributes]['a'].push('id')
        whitelist[:attributes]['li'] = %w(id)
        whitelist[:transformers].push(self.class.remove_non_footnote_ids)

        whitelist
      end

      class << self
        def remove_unsafe_table_style
          lambda do |env|
            node = env[:node]

            return unless node.name == 'th' || node.name == 'td'
            return unless node.has_attribute?('style')

            if node['style'] =~ TABLE_ALIGNMENT_PATTERN
              node['style'] = "text-align: #{$~[:alignment]}"
            else
              node.remove_attribute('style')
            end
          end
        end

        def remove_non_footnote_ids
          lambda do |env|
            node = env[:node]

            return unless node.name == 'a' || node.name == 'li'
            return unless node.has_attribute?('id')

            return if node.name == 'a' && node['id'] =~ Banzai::Filter::FootnoteFilter::FOOTNOTE_LINK_REFERENCE_PATTERN
            return if node.name == 'li' && node['id'] =~ Banzai::Filter::FootnoteFilter::FOOTNOTE_LI_REFERENCE_PATTERN

            node.remove_attribute('id')
          end
        end
      end
    end
  end
end
