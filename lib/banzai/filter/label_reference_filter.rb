# frozen_string_literal: true

module Banzai
  module Filter
    # HTML filter that replaces label references with links.
    class LabelReferenceFilter < AbstractReferenceFilter
      self.reference_type = :label

      def self.object_class
        Label
      end

      def find_object(parent_object, id)
        find_labels(parent_object).find(id)
      end

      def self.references_in(text, pattern = Label.reference_pattern)
        unescape_html_entities(text).gsub(pattern) do |match|
          yield match, $~[:label_id].to_i, $~[:label_name], $~[:project], $~[:namespace], $~
        end
      end

      def references_in(text, pattern = Label.reference_pattern)
        unescape_html_entities(text).gsub(pattern) do |match|
          namespace, project = $~[:namespace], $~[:project]
          project_path = full_project_path(namespace, project)
          label = find_label(project_path, $~[:label_id], $~[:label_name])

          if label
            yield match, label.id, project, namespace, $~
          else
            escape_html_entities(match)
          end
        end
      end

      def find_label(parent_ref, label_id, label_name)
        parent = parent_from_ref(parent_ref)
        return unless parent

        label_params = label_params(label_id, label_name)
        find_labels(parent).find_by(label_params)
      end

      def find_labels(parent)
        params = if parent.is_a?(Group)
                   { group_id: parent.id,
                     include_ancestor_groups: true,
                     only_group_labels: true }
                 else
                   { project: parent,
                     include_ancestor_groups: true }
                 end

        LabelsFinder.new(nil, params).execute(skip_authorization: true)
      end

      # Parameters to pass to `Label.find_by` based on the given arguments
      #
      # id   - Integer ID to pass. If present, returns {id: id}
      # name - String name to pass. If `id` is absent, finds by name without
      #        surrounding quotes.
      #
      # Returns a Hash.
      def label_params(id, name)
        if name
          { name: name.tr('"', '') }
        else
          { id: id.to_i }
        end
      end

      def url_for_object(label, parent)
        h = Gitlab::Routing.url_helpers

        if parent.is_a?(Project)
          h.project_issues_url(parent, label_name: label.name, only_path: context[:only_path])
        elsif context[:label_url_method]
          h.public_send(context[:label_url_method], parent, label_name: label.name, only_path: context[:only_path]) # rubocop:disable GitlabSecurity/PublicSend
        end
      end

      def object_link_text(object, matches)
        label_suffix = ''
        parent = project || group

        if project || full_path_ref?(matches)
          project_path    = full_project_path(matches[:namespace], matches[:project])
          parent_from_ref = from_ref_cached(project_path)
          reference       = parent_from_ref.to_human_reference(parent)

          label_suffix = " <i>in #{reference}</i>" if reference.present?
        end

        presenter = object.present(issuable_subject: parent)
        LabelsHelper.render_colored_label(presenter, label_suffix: label_suffix, title: tooltip_title(presenter))
      end

      def tooltip_title(label)
        nil
      end

      def full_path_ref?(matches)
        matches[:namespace] && matches[:project]
      end

      def object_link_title(object, matches)
        # use title of wrapped element instead
        nil
      end
    end
  end
end
