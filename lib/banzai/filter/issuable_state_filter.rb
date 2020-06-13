# frozen_string_literal: true

module Banzai
  module Filter
    # HTML filter that appends state information to issuable links.
    # Runs as a post-process filter as issuable state might change while
    # Markdown is in the cache.
    #
    # This filter supports cross-project references.
    class IssuableStateFilter < HTML::Pipeline::Filter
      VISIBLE_STATES = %w(closed merged).freeze

      def call
        return doc unless context[:issuable_state_filter_enabled]

        context = RenderContext.new(project, current_user)
        extractor = Banzai::IssuableExtractor.new(context)
        issuables = extractor.extract([doc])

        issuables.each do |node, issuable|
          next if !can_read_cross_project? && cross_referenced?(issuable)

          if VISIBLE_STATES.include?(issuable.state) && issuable_reference?(node.inner_html, issuable)
            state = moved_issue?(issuable) ? s_("IssuableStatus|moved") : issuable.state
            node.content += " (#{state})"
          end
        end

        doc
      end

      private

      def moved_issue?(issuable)
        issuable.instance_of?(Issue) && issuable.moved?
      end

      def issuable_reference?(text, issuable)
        CGI.unescapeHTML(text) == issuable.reference_link_text(project || group)
      end

      def cross_referenced?(issuable)
        return true if issuable.project != project
        return true if issuable.respond_to?(:group) && issuable.group != group

        false
      end

      def can_read_cross_project?
        Ability.allowed?(current_user, :read_cross_project)
      end

      def current_user
        context[:current_user]
      end

      def project
        context[:project]
      end

      def group
        context[:group]
      end
    end
  end
end
