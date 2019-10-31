# frozen_string_literal: true

module SystemNotes
  class BaseService
    attr_reader :noteable, :project, :author

    def initialize(noteable: nil, author: nil, project: nil)
      @noteable = noteable
      @project = project
      @author = author
    end

    protected

    def create_note(note_summary)
      note = Note.create(note_summary.note.merge(system: true))
      note.system_note_metadata = SystemNoteMetadata.new(note_summary.metadata) if note_summary.metadata?

      note
    end

    def content_tag(*args)
      ActionController::Base.helpers.content_tag(*args)
    end

    def url_helpers
      @url_helpers ||= Gitlab::Routing.url_helpers
    end
  end
end
