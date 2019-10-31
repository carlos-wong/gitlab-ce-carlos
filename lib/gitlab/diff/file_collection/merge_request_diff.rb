# frozen_string_literal: true

module Gitlab
  module Diff
    module FileCollection
      class MergeRequestDiff < MergeRequestDiffBase
        def diff_files
          diff_files = super

          diff_files.each { |diff_file| cache.decorate(diff_file) }

          diff_files
        end

        override :write_cache
        def write_cache
          cache.write_if_empty
        end

        override :clear_cache
        def clear_cache
          cache.clear
        end

        def cache_key
          cache.key
        end

        def real_size
          @merge_request_diff.real_size
        end

        private

        def cache
          @cache ||= Gitlab::Diff::HighlightCache.new(self)
        end
      end
    end
  end
end
