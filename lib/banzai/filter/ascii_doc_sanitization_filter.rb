# frozen_string_literal: true

module Banzai
  module Filter
    # Sanitize HTML produced by AsciiDoc/Asciidoctor.
    #
    # Extends Banzai::Filter::BaseSanitizationFilter with specific rules.
    class AsciiDocSanitizationFilter < Banzai::Filter::BaseSanitizationFilter
      # Section anchor link pattern
      SECTION_LINK_REF_PATTERN = /\A#{Gitlab::Asciidoc::DEFAULT_ADOC_ATTRS['idprefix']}(:?[[:alnum:]]|-|_)+\z/.freeze
      SECTION_HEADINGS = %w(h2 h3 h4 h5 h6).freeze

      # Footnote link patterns
      FOOTNOTE_LINK_ID_PATTERNS = {
        a: /\A_footnoteref_\d+\z/,
        div: /\A_footnotedef_\d+\z/
      }.freeze

      # Classes used by Asciidoctor to style components
      ADMONITION_CLASSES = %w(fa icon-note icon-tip icon-warning icon-caution icon-important).freeze
      CALLOUT_CLASSES = ['conum'].freeze
      CHECKLIST_CLASSES = %w(fa fa-check-square-o fa-square-o).freeze
      LIST_CLASSES = %w(checklist none no-bullet unnumbered unstyled).freeze

      TABLE_FRAME_CLASSES = %w(frame-all frame-topbot frame-sides frame-ends frame-none).freeze
      TABLE_GRID_CLASSES = %w(grid-all grid-rows grid-cols grid-none).freeze
      TABLE_STRIPES_CLASSES = %w(stripes-all stripes-odd stripes-even stripes-hover stripes-none).freeze

      ELEMENT_CLASSES_WHITELIST = {
        span: %w(big small underline overline line-through).freeze,
        div: ['admonitionblock'].freeze,
        td: ['icon'].freeze,
        i: ADMONITION_CLASSES + CALLOUT_CLASSES + CHECKLIST_CLASSES,
        ul: LIST_CLASSES,
        ol: LIST_CLASSES,
        a: ['anchor'].freeze,
        table: TABLE_FRAME_CLASSES + TABLE_GRID_CLASSES + TABLE_STRIPES_CLASSES
      }.freeze

      def customize_whitelist(whitelist)
        # Allow marks
        whitelist[:elements].push('mark')

        # Allow any classes in `span`, `i`, `div`, `td`, `ul`, `ol` and `a` elements
        # but then remove any unknown classes
        whitelist[:attributes]['span'] = %w(class)
        whitelist[:attributes]['div'].push('class')
        whitelist[:attributes]['td'] = %w(class)
        whitelist[:attributes]['i'] = %w(class)
        whitelist[:attributes]['ul'] = %w(class)
        whitelist[:attributes]['ol'] = %w(class)
        whitelist[:attributes]['a'].push('class')
        whitelist[:attributes]['table'] = %w(class)
        whitelist[:transformers].push(self.class.remove_element_classes)

        # Allow `id` in heading elements for section anchors
        SECTION_HEADINGS.each do |header|
          whitelist[:attributes][header] = %w(id)
        end
        whitelist[:transformers].push(self.class.remove_non_heading_ids)

        # Allow `id` in footnote elements
        FOOTNOTE_LINK_ID_PATTERNS.keys.each do |element|
          whitelist[:attributes][element.to_s].push('id')
        end
        whitelist[:transformers].push(self.class.remove_non_footnote_ids)

        whitelist
      end

      class << self
        def remove_non_footnote_ids
          lambda do |env|
            node = env[:node]

            return unless (pattern = FOOTNOTE_LINK_ID_PATTERNS[node.name.to_sym])
            return unless node.has_attribute?('id')

            return if node['id'] =~ pattern

            node.remove_attribute('id')
          end
        end

        def remove_non_heading_ids
          lambda do |env|
            node = env[:node]

            return unless SECTION_HEADINGS.any?(node.name)
            return unless node.has_attribute?('id')

            return if node['id'] =~ SECTION_LINK_REF_PATTERN

            node.remove_attribute('id')
          end
        end

        def remove_element_classes
          lambda do |env|
            node = env[:node]

            return unless (classes_whitelist = ELEMENT_CLASSES_WHITELIST[node.name.to_sym])
            return unless node.has_attribute?('class')

            classes = node['class'].strip.split(' ')
            allowed_classes = (classes & classes_whitelist)
            if allowed_classes.empty?
              node.remove_attribute('class')
            else
              node['class'] = allowed_classes.join(' ')
            end
          end
        end
      end
    end
  end
end
