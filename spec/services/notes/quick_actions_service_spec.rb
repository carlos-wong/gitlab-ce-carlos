# frozen_string_literal: true

require 'spec_helper'

describe Notes::QuickActionsService do
  shared_context 'note on noteable' do
    let(:project) { create(:project, :repository) }
    let(:maintainer) { create(:user).tap { |u| project.add_maintainer(u) } }
    let(:assignee) { create(:user) }

    before do
      project.add_maintainer(assignee)
    end
  end

  shared_examples 'note on noteable that supports quick actions' do
    include_context 'note on noteable'

    before do
      note.note = note_text
    end

    let!(:milestone) { create(:milestone, project: project) }
    let!(:labels) { create_pair(:label, project: project) }

    describe 'note with only command' do
      describe '/close, /label, /assign & /milestone' do
        let(:note_text) do
          %(/close\n/label ~#{labels.first.name} ~#{labels.last.name}\n/assign @#{assignee.username}\n/milestone %"#{milestone.name}")
        end

        it 'closes noteable, sets labels, assigns, and sets milestone to noteable, and leave no note' do
          content, update_params = service.execute(note)
          service.apply_updates(update_params, note)

          expect(content).to eq ''
          expect(note.noteable).to be_closed
          expect(note.noteable.labels).to match_array(labels)
          expect(note.noteable.assignees).to eq([assignee])
          expect(note.noteable.milestone).to eq(milestone)
        end
      end

      describe '/reopen' do
        before do
          note.noteable.close!
          expect(note.noteable).to be_closed
        end
        let(:note_text) { '/reopen' }

        it 'opens the noteable, and leave no note' do
          content, update_params = service.execute(note)
          service.apply_updates(update_params, note)

          expect(content).to eq ''
          expect(note.noteable).to be_open
        end
      end

      describe '/spend' do
        let(:note_text) { '/spend 1h' }

        it 'updates the spent time on the noteable' do
          content, update_params = service.execute(note)
          service.apply_updates(update_params, note)

          expect(content).to eq ''
          expect(note.noteable.time_spent).to eq(3600)
        end
      end
    end

    describe 'note with command & text' do
      describe '/close, /label, /assign & /milestone' do
        let(:note_text) do
          %(HELLO\n/close\n/label ~#{labels.first.name} ~#{labels.last.name}\n/assign @#{assignee.username}\n/milestone %"#{milestone.name}"\nWORLD)
        end

        it 'closes noteable, sets labels, assigns, and sets milestone to noteable' do
          content, update_params = service.execute(note)
          service.apply_updates(update_params, note)

          expect(content).to eq "HELLO\nWORLD"
          expect(note.noteable).to be_closed
          expect(note.noteable.labels).to match_array(labels)
          expect(note.noteable.assignees).to eq([assignee])
          expect(note.noteable.milestone).to eq(milestone)
        end
      end

      describe '/reopen' do
        before do
          note.noteable.close
          expect(note.noteable).to be_closed
        end
        let(:note_text) { "HELLO\n/reopen\nWORLD" }

        it 'opens the noteable' do
          content, update_params = service.execute(note)
          service.apply_updates(update_params, note)

          expect(content).to eq "HELLO\nWORLD"
          expect(note.noteable).to be_open
        end
      end
    end
  end

  describe '.noteable_update_service' do
    include_context 'note on noteable'

    it 'returns Issues::UpdateService for a note on an issue' do
      note = create(:note_on_issue, project: project)

      expect(described_class.noteable_update_service(note)).to eq(Issues::UpdateService)
    end

    it 'returns MergeRequests::UpdateService for a note on a merge request' do
      note = create(:note_on_merge_request, project: project)

      expect(described_class.noteable_update_service(note)).to eq(MergeRequests::UpdateService)
    end

    it 'returns Commits::TagService for a note on a commit' do
      note = create(:note_on_commit, project: project)

      expect(described_class.noteable_update_service(note)).to eq(Commits::TagService)
    end
  end

  describe '.supported?' do
    include_context 'note on noteable'

    let(:note) { create(:note_on_issue, project: project) }

    context 'with a note on an issue' do
      it 'returns true' do
        expect(described_class.supported?(note)).to be_truthy
      end
    end

    context 'with a note on a commit' do
      let(:note) { create(:note_on_commit, project: project) }

      it 'returns false' do
        expect(described_class.supported?(note)).to be_truthy
      end
    end
  end

  describe '#supported?' do
    include_context 'note on noteable'

    it 'delegates to the class method' do
      service = described_class.new(project, maintainer)
      note = create(:note_on_issue, project: project)

      expect(described_class).to receive(:supported?).with(note)

      service.supported?(note)
    end
  end

  describe '#execute' do
    let(:service) { described_class.new(project, maintainer) }

    it_behaves_like 'note on noteable that supports quick actions' do
      let(:note) { build(:note_on_issue, project: project) }
    end

    it_behaves_like 'note on noteable that supports quick actions' do
      let(:note) { build(:note_on_merge_request, project: project) }
    end
  end

  context 'CE restriction for issue assignees' do
    describe '/assign' do
      let(:project) { create(:project) }
      let(:assignee) { create(:user) }
      let(:maintainer) { create(:user) }
      let(:service) { described_class.new(project, maintainer) }
      let(:note) { create(:note_on_issue, note: note_text, project: project) }

      let(:note_text) do
        %(/assign @#{assignee.username} @#{maintainer.username}\n")
      end

      before do
        stub_licensed_features(multiple_issue_assignees: false)
        project.add_maintainer(maintainer)
        project.add_maintainer(assignee)
      end

      it 'adds only one assignee from the list' do
        _, update_params = service.execute(note)
        service.apply_updates(update_params, note)

        expect(note.noteable.assignees.count).to eq(1)
      end
    end
  end
end
