# frozen_string_literal: true

RSpec.shared_examples 'system note creation' do |update_params, note_text|
  subject { described_class.new(project, user).execute(issuable, old_labels: []) }

  before do
    issuable.assign_attributes(update_params)
    issuable.save
  end

  it 'creates 1 system note with the correct content' do
    expect { subject }.to change { Note.count }.from(0).to(1)

    note = Note.last
    expect(note.note).to match(note_text)
    expect(note.noteable_type).to eq(issuable.class.name)
  end
end

RSpec.shared_examples 'WIP notes creation' do |wip_action|
  subject { described_class.new(project, user).execute(issuable, old_labels: []) }

  it 'creates WIP toggle and title change notes' do
    expect { subject }.to change { Note.count }.from(0).to(2)

    expect(Note.first.note).to match("#{wip_action} as a **Work In Progress**")
    expect(Note.second.note).to match('changed title')
  end
end

RSpec.shared_examples 'a note with overridable created_at' do
  let(:noteable) { create(:issue, project: project, system_note_timestamp: Time.at(42)) }

  it 'the note has the correct time' do
    expect(subject.created_at).to eq Time.at(42)
  end
end

RSpec.shared_examples 'a system note' do |params|
  let(:expected_noteable) { noteable }
  let(:commit_count)      { nil }

  it 'has the correct attributes', :aggregate_failures do
    exclude_project = !params.nil? && params[:exclude_project]

    expect(subject).to be_valid
    expect(subject).to be_system

    expect(subject.noteable).to eq expected_noteable
    expect(subject.project).to eq project unless exclude_project
    expect(subject.author).to eq author

    expect(subject.system_note_metadata.action).to eq(action)
    expect(subject.system_note_metadata.commit_count).to eq(commit_count)
  end
end
