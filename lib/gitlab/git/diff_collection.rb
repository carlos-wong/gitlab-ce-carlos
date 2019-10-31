# frozen_string_literal: true

# Gitaly note: JV: no RPC's here.

module Gitlab
  module Git
    class DiffCollection
      include Enumerable

      DEFAULT_LIMITS = { max_files: 100, max_lines: 5000 }.freeze

      attr_reader :limits

      delegate :max_files, :max_lines, :max_bytes, :safe_max_files, :safe_max_lines, :safe_max_bytes, to: :limits

      def self.limits(options = {})
        limits = {}
        limits[:max_files] = options.fetch(:max_files, DEFAULT_LIMITS[:max_files])
        limits[:max_lines] = options.fetch(:max_lines, DEFAULT_LIMITS[:max_lines])
        limits[:max_bytes] = limits[:max_files] * 5.kilobytes # Average 5 KB per file
        limits[:safe_max_files] = [limits[:max_files], DEFAULT_LIMITS[:max_files]].min
        limits[:safe_max_lines] = [limits[:max_lines], DEFAULT_LIMITS[:max_lines]].min
        limits[:safe_max_bytes] = limits[:safe_max_files] * 5.kilobytes # Average 5 KB per file
        limits[:max_patch_bytes] = Gitlab::Git::Diff.patch_hard_limit_bytes

        OpenStruct.new(limits)
      end

      def initialize(iterator, options = {})
        @iterator = iterator
        @limits = self.class.limits(options)
        @enforce_limits = !!options.fetch(:limits, true)
        @expanded = !!options.fetch(:expanded, true)
        @offset_index = options.fetch(:offset_index, 0)

        @line_count = 0
        @byte_count = 0
        @overflow = false
        @empty = true
        @array = Array.new
      end

      def each(&block)
        @array.each(&block)

        return if @overflow
        return if @iterator.nil?

        if @iterator.is_a?(Gitlab::GitalyClient::DiffStitcher)
          each_gitaly_patch(&block)
        else
          each_serialized_patch(&block)
        end

        @populated = true

        # Allow iterator to be garbage-collected. It cannot be reused anyway.
        @iterator = nil
      end

      def empty?
        any? # Make sure the iterator has been exercised
        @empty
      end

      def overflow?
        populate!
        !!@overflow
      end

      def size
        @size ||= count # forces a loop using each method
      end

      def real_size
        populate!

        if @overflow
          "#{size}+"
        else
          size.to_s
        end
      end

      def line_count
        populate!

        @line_count
      end

      def decorate!
        collection = each_with_index do |element, i|
          @array[i] = yield(element)
        end
        collection
      end

      alias_method :to_ary, :to_a

      private

      def populate!
        return if @populated

        each { nil } # force a loop through all diffs
        nil
      end

      def over_safe_limits?(files)
        files >= safe_max_files || @line_count > safe_max_lines || @byte_count >= safe_max_bytes
      end

      def each_gitaly_patch
        i = @array.length

        @iterator.each do |raw|
          diff = Gitlab::Git::Diff.new(raw, expanded: !@enforce_limits || @expanded)

          if raw.overflow_marker
            @overflow = true
            break
          end

          yield @array[i] = diff
          i += 1
        end
      end

      def each_serialized_patch
        i = @array.length

        @iterator.each_with_index do |raw, iterator_index|
          @empty = false

          if @enforce_limits && i >= max_files
            @overflow = true
            break
          end

          expanded = !@enforce_limits || @expanded

          diff = Gitlab::Git::Diff.new(raw, expanded: expanded)

          if !expanded && over_safe_limits?(i) && diff.line_count > 0
            diff.collapse!
          end

          @line_count += diff.line_count
          @byte_count += diff.diff.bytesize

          if @enforce_limits && (@line_count >= max_lines || @byte_count >= max_bytes)
            # This last Diff instance pushes us over the lines limit. We stop and
            # discard it.
            @overflow = true
            break
          end

          # We should not yield / memoize diffs before the offset index. Though,
          # we still consider the limit buffers for diffs before it.
          if iterator_index >= @offset_index
            yield @array[i] = diff
            i += 1
          end
        end
      end
    end
  end
end
