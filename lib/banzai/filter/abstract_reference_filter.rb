# frozen_string_literal: true

module Banzai
  module Filter
    # Issues, Merge Requests, Snippets, Commits and Commit Ranges share
    # similar functionality in reference filtering.
    class AbstractReferenceFilter < ReferenceFilter
      include CrossProjectReference

      def self.object_class
        # Implement in child class
        # Example: MergeRequest
      end

      def self.object_name
        @object_name ||= object_class.name.underscore
      end

      def self.object_sym
        @object_sym ||= object_name.to_sym
      end

      # Public: Find references in text (like `!123` for merge requests)
      #
      #   AnyReferenceFilter.references_in(text) do |match, id, project_ref, matches|
      #     object = find_object(project_ref, id)
      #     "<a href=...>#{object.to_reference}</a>"
      #   end
      #
      # text - String text to search.
      #
      # Yields the String match, the Integer referenced object ID, an optional String
      # of the external project reference, and all of the matchdata.
      #
      # Returns a String replaced with the return of the block.
      def self.references_in(text, pattern = object_class.reference_pattern)
        text.gsub(pattern) do |match|
          symbol = $~[object_sym]
          if object_class.reference_valid?(symbol)
            yield match, symbol.to_i, $~[:project], $~[:namespace], $~
          else
            match
          end
        end
      end

      def object_class
        self.class.object_class
      end

      def object_sym
        self.class.object_sym
      end

      def references_in(*args, &block)
        self.class.references_in(*args, &block)
      end

      # Implement in child class
      # Example: project.merge_requests.find
      def find_object(parent_object, id)
      end

      # Override if the link reference pattern produces a different ID (global
      # ID vs internal ID, for instance) to the regular reference pattern.
      def find_object_from_link(parent_object, id)
        find_object(parent_object, id)
      end

      # Implement in child class
      # Example: project_merge_request_url
      def url_for_object(object, parent_object)
      end

      def find_object_cached(parent_object, id)
        cached_call(:banzai_find_object, id, path: [object_class, parent_object.id]) do
          find_object(parent_object, id)
        end
      end

      def find_object_from_link_cached(parent_object, id)
        cached_call(:banzai_find_object_from_link, id, path: [object_class, parent_object.id]) do
          find_object_from_link(parent_object, id)
        end
      end

      def from_ref_cached(ref)
        cached_call("banzai_#{parent_type}_refs".to_sym, ref) do
          parent_from_ref(ref)
        end
      end

      def url_for_object_cached(object, parent_object)
        cached_call(:banzai_url_for_object, object, path: [object_class, parent_object.id]) do
          url_for_object(object, parent_object)
        end
      end

      def call
        return doc unless project || group

        ref_pattern = object_class.reference_pattern
        link_pattern = object_class.link_reference_pattern

        # Compile often used regexps only once outside of the loop
        ref_pattern_anchor = /\A#{ref_pattern}\z/
        link_pattern_start = /\A#{link_pattern}/
        link_pattern_anchor = /\A#{link_pattern}\z/

        nodes.each do |node|
          if text_node?(node) && ref_pattern
            replace_text_when_pattern_matches(node, ref_pattern) do |content|
              object_link_filter(content, ref_pattern)
            end

          elsif element_node?(node)
            yield_valid_link(node) do |link, inner_html|
              if ref_pattern && link =~ ref_pattern_anchor
                replace_link_node_with_href(node, link) do
                  object_link_filter(link, ref_pattern, link_content: inner_html)
                end

                next
              end

              next unless link_pattern

              if link == inner_html && inner_html =~ link_pattern_start
                replace_link_node_with_text(node, link) do
                  object_link_filter(inner_html, link_pattern, link_reference: true)
                end

                next
              end

              if link =~ link_pattern_anchor
                replace_link_node_with_href(node, link) do
                  object_link_filter(link, link_pattern, link_content: inner_html, link_reference: true)
                end

                next
              end
            end
          end
        end

        doc
      end

      # Replace references (like `!123` for merge requests) in text with links
      # to the referenced object's details page.
      #
      # text - String text to replace references in.
      # pattern - Reference pattern to match against.
      # link_content - Original content of the link being replaced.
      # link_reference - True if this was using the link reference pattern,
      #                  false otherwise.
      #
      # Returns a String with references replaced with links. All links
      # have `gfm` and `gfm-OBJECT_NAME` class names attached for styling.
      def object_link_filter(text, pattern, link_content: nil, link_reference: false)
        references_in(text, pattern) do |match, id, project_ref, namespace_ref, matches|
          parent_path = if parent_type == :group
                          full_group_path(namespace_ref)
                        else
                          full_project_path(namespace_ref, project_ref)
                        end

          parent = from_ref_cached(parent_path)

          if parent
            object =
              if link_reference
                find_object_from_link_cached(parent, id)
              else
                find_object_cached(parent, id)
              end
          end

          if object
            title = object_link_title(object, matches)
            klass = reference_class(object_sym)

            data_attributes = data_attributes_for(link_content || match, parent, object,
                                                  link_content: !!link_content,
                                                  link_reference: link_reference)
            data = data_attribute(data_attributes)

            url =
              if matches.names.include?("url") && matches[:url]
                matches[:url]
              else
                url_for_object_cached(object, parent)
              end

            content = link_content || object_link_text(object, matches)

            link = %(<a href="#{url}" #{data}
                        title="#{escape_once(title)}"
                        class="#{klass}">#{content}</a>)

            wrap_link(link, object)
          else
            match
          end
        end
      end

      def wrap_link(link, object)
        link
      end

      def data_attributes_for(text, parent, object, link_content: false, link_reference: false)
        object_parent_type = parent.is_a?(Group) ? :group : :project

        {
          original:             text,
          link:                 link_content,
          link_reference:       link_reference,
          object_parent_type => parent.id,
          object_sym =>         object.id
        }
      end

      def object_link_text_extras(object, matches)
        extras = []

        if matches.names.include?("anchor") && matches[:anchor] && matches[:anchor] =~ /\A\#note_(\d+)\z/
          extras << "comment #{$1}"
        end

        extension = matches[:extension] if matches.names.include?("extension")

        extras << extension if extension

        extras
      end

      def object_link_title(object, matches)
        object.title
      end

      def object_link_text(object, matches)
        parent = context[:project] || context[:group]
        text = object.reference_link_text(parent)

        extras = object_link_text_extras(object, matches)
        text += " (#{extras.join(", ")})" if extras.any?

        text
      end

      # Returns a Hash containing all object references (e.g. issue IDs) per the
      # project they belong to.
      def references_per_parent
        @references_per ||= {}

        @references_per[parent_type] ||= begin
          refs = Hash.new { |hash, key| hash[key] = Set.new }

          regex = Regexp.union(object_class.reference_pattern, object_class.link_reference_pattern)

          nodes.each do |node|
            node.to_html.scan(regex) do
              path = if parent_type == :project
                       full_project_path($~[:namespace], $~[:project])
                     else
                       full_group_path($~[:group])
                     end

              symbol = $~[object_sym]
              refs[path] << symbol if object_class.reference_valid?(symbol)
            end
          end

          refs
        end
      end

      # Returns a Hash containing referenced projects grouped per their full
      # path.
      def parent_per_reference
        @per_reference ||= {}

        @per_reference[parent_type] ||= begin
          refs = Set.new

          references_per_parent.each do |ref, _|
            refs << ref
          end

          find_for_paths(refs.to_a).index_by(&:full_path)
        end
      end

      def relation_for_paths(paths)
        klass = parent_type.to_s.camelize.constantize
        result = klass.where_full_path_in(paths)
        return result if parent_type == :group

        result.includes(:namespace) if parent_type == :project
      end

      # Returns projects for the given paths.
      def find_for_paths(paths)
        if Gitlab::SafeRequestStore.active?
          cache = refs_cache
          to_query = paths - cache.keys

          unless to_query.empty?
            records = relation_for_paths(to_query)

            found = []
            records.each do |record|
              ref = record.full_path
              get_or_set_cache(cache, ref) { record }
              found << ref
            end

            not_found = to_query - found
            not_found.each do |ref|
              get_or_set_cache(cache, ref) { nil }
            end
          end

          cache.slice(*paths).values.compact
        else
          relation_for_paths(paths)
        end
      end

      def current_parent_path
        @current_parent_path ||= parent&.full_path
      end

      def current_project_namespace_path
        @current_project_namespace_path ||= project&.namespace&.full_path
      end

      private

      def full_project_path(namespace, project_ref)
        return current_parent_path unless project_ref

        namespace_ref = namespace || current_project_namespace_path
        "#{namespace_ref}/#{project_ref}"
      end

      def refs_cache
        Gitlab::SafeRequestStore["banzai_#{parent_type}_refs".to_sym] ||= {}
      end

      def parent_type
        :project
      end

      def parent
        parent_type == :project ? project : group
      end

      def full_group_path(group_ref)
        return current_parent_path unless group_ref

        group_ref
      end

      def unescape_html_entities(text)
        CGI.unescapeHTML(text.to_s)
      end

      def escape_html_entities(text)
        CGI.escapeHTML(text.to_s)
      end
    end
  end
end
