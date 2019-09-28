# frozen_string_literal: true

class LabelNote < Note
  attr_accessor :resource_parent
  attr_reader :events

  def self.from_events(events, resource: nil, resource_parent: nil)
    resource ||= events.first.issuable

    attrs = {
      system: true,
      author: events.first.user,
      created_at: events.first.created_at,
      discussion_id: events.first.discussion_id,
      noteable: resource,
      system_note_metadata: SystemNoteMetadata.new(action: 'label'),
      events: events,
      resource_parent: resource_parent
    }

    if resource_parent.is_a?(Project)
      attrs[:project_id] = resource_parent.id
    end

    LabelNote.new(attrs)
  end

  def events=(events)
    @events = events

    update_outdated_markdown
  end

  def cached_html_up_to_date?(markdown_field)
    true
  end

  def note
    @note ||= note_text
  end

  def note_html
    @note_html ||= "<p dir=\"auto\">#{note_text(html: true)}</p>"
  end

  def project
    resource_parent if resource_parent.is_a?(Project)
  end

  def group
    resource_parent if resource_parent.is_a?(Group)
  end

  private

  def update_outdated_markdown
    events.each do |event|
      if event.outdated_markdown?
        event.refresh_invalid_reference
      end
    end
  end

  def note_text(html: false)
    added = labels_str(label_refs_by_action('add', html), prefix: 'added', suffix: added_suffix)
    removed = labels_str(label_refs_by_action('remove', html), prefix: removed_prefix)

    [added, removed].compact.join(' and ')
  end

  def removed_prefix
    'removed'
  end

  def added_suffix
    ''
  end

  # returns string containing added/removed labels including
  # count of deleted labels:
  #
  # added ~1 ~2 + 1 deleted label
  # added 3 deleted labels
  # added ~1 ~2 labels
  def labels_str(label_refs, prefix: '', suffix: '')
    existing_refs = label_refs.select { |ref| ref.present? }.sort
    refs_str = existing_refs.empty? ? nil : existing_refs.join(' ')

    deleted = label_refs.count - existing_refs.count
    deleted_str = deleted == 0 ? nil : "#{deleted} deleted"

    return unless refs_str || deleted_str

    label_list_str = [refs_str, deleted_str].compact.join(' + ')
    suffix += ' label'.pluralize(deleted > 0 ? deleted : existing_refs.count)

    "#{prefix} #{label_list_str} #{suffix.squish}"
  end

  def label_refs_by_action(action, html)
    field = html ? :reference_html : :reference

    events.select { |e| e.action == action }.map(&field)
  end
end

LabelNote.prepend_if_ee('EE::LabelNote')
