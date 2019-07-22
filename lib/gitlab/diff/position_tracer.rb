# frozen_string_literal: true

# Finds the diff position in the new diff that corresponds to the same location
# specified by the provided position in the old diff.
module Gitlab
  module Diff
    class PositionTracer
      attr_accessor :project
      attr_accessor :old_diff_refs
      attr_accessor :new_diff_refs
      attr_accessor :paths

      def initialize(project:, old_diff_refs:, new_diff_refs:, paths: nil)
        @project = project
        @old_diff_refs = old_diff_refs
        @new_diff_refs = new_diff_refs
        @paths = paths
      end

      def trace(old_position)
        return unless old_diff_refs&.complete? && new_diff_refs&.complete?
        return unless old_position.diff_refs == old_diff_refs

        strategy = old_position.on_text? ? LineStrategy : ImageStrategy

        strategy.new(self).trace(old_position)
      end

      def ac_diffs
        @ac_diffs ||= compare(
          old_diff_refs.base_sha || old_diff_refs.start_sha,
          new_diff_refs.base_sha || new_diff_refs.start_sha,
          straight: true
        )
      end

      def bd_diffs
        @bd_diffs ||= compare(old_diff_refs.head_sha, new_diff_refs.head_sha, straight: true)
      end

      def cd_diffs
        @cd_diffs ||= compare(new_diff_refs.start_sha, new_diff_refs.head_sha)
      end

      private

      def compare(start_sha, head_sha, straight: false)
        compare = CompareService.new(project, head_sha).execute(project, start_sha, straight: straight)
        compare.diffs(paths: paths, expanded: true)
      end
    end
  end
end
