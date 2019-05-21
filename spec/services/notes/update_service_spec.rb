# frozen_string_literal: true

require 'spec_helper'

describe Notes::UpdateService do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:user2) { create(:user) }
  let(:user3) { create(:user) }
  let(:issue) { create(:issue, project: project) }
  let(:note) { create(:note, project: project, noteable: issue, author: user, note: "Old note #{user2.to_reference}") }

  before do
    project.add_maintainer(user)
    project.add_developer(user2)
    project.add_developer(user3)
  end

  describe '#execute' do
    def update_note(opts)
      @note = Notes::UpdateService.new(project, user, opts).execute(note)
      @note.reload
    end

    context 'suggestions' do
      it 'refreshes note suggestions' do
        markdown = <<-MARKDOWN.strip_heredoc
          ```suggestion
            foo
          ```

          ```suggestion
            bar
          ```
        MARKDOWN

        suggestion = create(:suggestion)
        note = suggestion.note

        expect { described_class.new(project, user, note: markdown).execute(note) }
          .to change { note.suggestions.count }.from(1).to(2)

        expect(note.suggestions.order(:relative_order).map(&:to_content))
          .to eq(["  foo\n", "  bar\n"])
      end
    end

    context 'todos' do
      let!(:todo) { create(:todo, :assigned, user: user, project: project, target: issue, author: user2) }

      context 'when the note change' do
        before do
          update_note({ note: "New note #{user2.to_reference} #{user3.to_reference}" })
        end

        it 'marks todos as done' do
          expect(todo.reload).to be_done
        end

        it 'creates only 1 new todo' do
          expect(Todo.count).to eq(2)
        end
      end

      context 'when the note does not change' do
        before do
          update_note({ note: "Old note #{user2.to_reference}" })
        end

        it 'keep todos' do
          expect(todo.reload).to be_pending
        end

        it 'does not create any new todos' do
          expect(Todo.count).to eq(1)
        end
      end
    end
  end
end
