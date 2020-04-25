# frozen_string_literal: true

RSpec.shared_examples 'reportable note' do |type|
  include MobileHelpers
  include NotesHelper

  let(:comment) { find("##{ActionView::RecordIdentifier.dom_id(note)}") }
  let(:more_actions_selector) { '.more-actions.dropdown' }
  let(:abuse_report_path) { new_abuse_report_path(user_id: note.author.id, ref_url: noteable_note_url(note)) }

  it 'has an edit button' do
    expect(comment).to have_selector('.js-note-edit')
  end

  it 'has a `More actions` dropdown' do
    expect(comment).to have_selector(more_actions_selector)
  end

  it 'dropdown has Report and Delete links' do
    dropdown = comment.find(more_actions_selector)
    open_dropdown(dropdown)

    expect(dropdown).to have_link('Report abuse to admin', href: abuse_report_path)

    if type == 'issue' || type == 'merge_request'
      expect(dropdown).to have_button('Delete comment')
    else
      expect(dropdown).to have_link('Delete comment', href: note_url(note, project))
    end
  end

  it 'Report button links to a report page' do
    dropdown = comment.find(more_actions_selector)
    open_dropdown(dropdown)

    dropdown.click_link('Report abuse to admin')

    expect(find('#user_name')['value']).to match(note.author.username)
    expect(find('#abuse_report_message')['value']).to match(noteable_note_url(note))
  end

  def open_dropdown(dropdown)
    # make window wide enough that tooltip doesn't trigger horizontal scrollbar
    restore_window_size

    dropdown.find('.more-actions-toggle').click
    dropdown.find('.dropdown-menu li', match: :first)
  end
end
