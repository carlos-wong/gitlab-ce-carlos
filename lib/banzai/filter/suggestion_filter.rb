# frozen_string_literal: true

# Generated HTML is transformed back to GFM by app/assets/javascripts/behaviors/markdown/nodes/code_block.js
module Banzai
  module Filter
    class SuggestionFilter < HTML::Pipeline::Filter
      # Class used for tagging elements that should be rendered
      TAG_CLASS = 'js-render-suggestion'

      def call
        return doc unless suggestions_filter_enabled?

        doc.search('pre.suggestion > code').each do |node|
          node.add_class(TAG_CLASS)
        end

        doc
      end

      def suggestions_filter_enabled?
        context[:suggestions_filter_enabled]
      end

      private

      def project
        context[:project]
      end
    end
  end
end
