# frozen_string_literal: true

# Generated HTML is transformed back to GFM by app/assets/javascripts/behaviors/markdown/nodes/code_block.js
module Banzai
  module Filter
    class MermaidFilter < HTML::Pipeline::Filter
      def call
        doc.css('pre[lang="mermaid"] > code').add_class('js-render-mermaid')

        doc
      end
    end
  end
end
