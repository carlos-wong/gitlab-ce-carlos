# frozen_string_literal: true

module API
  module Helpers
    module NotesHelpers
      include ::RendersNotes

      def self.noteable_types
        # This is a method instead of a constant, allowing EE to more easily
        # extend it.
        [Issue, MergeRequest, Snippet]
      end

      def update_note(noteable, note_id)
        note = noteable.notes.find(note_id)

        authorize! :admin_note, note

        opts = {
          note: params[:body]
        }
        parent = noteable_parent(noteable)
        project = parent if parent.is_a?(Project)

        note = ::Notes::UpdateService.new(project, current_user, opts).execute(note)

        if note.valid?
          present note, with: Entities::Note
        else
          bad_request!("Failed to save note #{note.errors.messages}")
        end
      end

      def resolve_note(noteable, note_id, resolved)
        note = noteable.notes.find(note_id)

        authorize! :resolve_note, note

        bad_request!("Note is not resolvable") unless note.resolvable?

        if resolved
          parent = noteable_parent(noteable)
          ::Notes::ResolveService.new(parent, current_user).execute(note)
        else
          note.unresolve!
        end

        present note, with: Entities::Note
      end

      def delete_note(noteable, note_id)
        note = noteable.notes.find(note_id)

        authorize! :admin_note, note

        parent = noteable_parent(noteable)
        project = parent if parent.is_a?(Project)
        destroy_conditionally!(note) do |note|
          ::Notes::DestroyService.new(project, current_user).execute(note)
        end
      end

      def get_note(noteable, note_id)
        note = noteable.notes.with_metadata.find(note_id)
        can_read_note = note.visible_for?(current_user)

        if can_read_note
          present note, with: Entities::Note
        else
          not_found!("Note")
        end
      end

      def noteable_read_ability_name(noteable)
        "read_#{ability_name(noteable)}".to_sym
      end

      def ability_name(noteable)
        if noteable.respond_to?(:to_ability_name)
          noteable.to_ability_name
        else
          noteable.class.to_s.underscore
        end
      end

      def find_noteable(noteable_type, noteable_id)
        params = finder_params_by_noteable_type_and_id(noteable_type, noteable_id)

        noteable = NotesFinder.new(current_user, params).target
        noteable = nil unless can?(current_user, noteable_read_ability_name(noteable), noteable)
        noteable || not_found!(noteable_type)
      end

      def finder_params_by_noteable_type_and_id(type, id)
        target_type = type.name.underscore
        { target_type: target_type }.tap do |h|
          if %w(issue merge_request).include?(target_type)
            h[:target_iid] = id
          else
            h[:target_id] = id
          end

          add_parent_to_finder_params(h, type)
        end
      end

      def add_parent_to_finder_params(finder_params, noteable_type)
        finder_params[:project] = user_project
      end

      def noteable_parent(noteable)
        public_send("user_#{noteable.class.parent_class.to_s.underscore}") # rubocop:disable GitlabSecurity/PublicSend
      end

      def create_note(noteable, opts)
        authorize!(:create_note, noteable)

        parent = noteable_parent(noteable)

        opts.delete(:created_at) unless current_user.can?(:set_note_created_at, noteable)

        opts[:updated_at] = opts[:created_at] if opts[:created_at]

        project = parent if parent.is_a?(Project)
        ::Notes::CreateService.new(project, current_user, opts).execute
      end

      def resolve_discussion(noteable, discussion_id, resolved)
        discussion = noteable.find_discussion(discussion_id)

        forbidden! unless discussion.can_resolve?(current_user)

        if resolved
          parent = noteable_parent(noteable)
          ::Discussions::ResolveService.new(parent, current_user, merge_request: noteable).execute(discussion)
        else
          discussion.unresolve!
        end

        present discussion, with: Entities::Discussion
      end
    end
  end
end

API::Helpers::NotesHelpers.prepend_if_ee('EE::API::Helpers::NotesHelpers')
