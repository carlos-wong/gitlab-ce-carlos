# frozen_string_literal: true

module Banzai
  module Pipeline
    class EmailPipeline < FullPipeline
      def self.filters
        super.tap do |filter_array|
          filter_array.delete(Banzai::Filter::ImageLazyLoadFilter)
        end
      end

      def self.transform_context(context)
        super(context).merge(
          only_path: false,
          emailable_links: true,
          no_sourcepos: true
        )
      end
    end
  end
end
