# frozen_string_literal: true

require 'spec_helper'

describe NotePolicy do
  describe '#rules' do
    let(:user) { create(:user) }
    let(:project) { create(:project, :public) }
    let(:issue) { create(:issue, project: project) }
    let(:noteable) { issue }
    let(:policy) { described_class.new(user, note) }
    let(:note) { create(:note, noteable: noteable, author: user, project: project) }

    shared_examples_for 'a discussion with a private noteable' do
      context 'when the note author can no longer see the noteable' do
        it 'can not edit nor read the note' do
          expect(policy).to be_disallowed(:admin_note)
          expect(policy).to be_disallowed(:resolve_note)
          expect(policy).to be_disallowed(:read_note)
          expect(policy).to be_disallowed(:award_emoji)
        end
      end

      context 'when the note author can still see the noteable' do
        before do
          project.add_developer(user)
        end

        it 'can edit the note' do
          expect(policy).to be_allowed(:admin_note)
          expect(policy).to be_allowed(:resolve_note)
          expect(policy).to be_allowed(:read_note)
          expect(policy).to be_allowed(:award_emoji)
        end
      end
    end

    context 'when the noteable is a deleted commit' do
      let(:commit) { nil }
      let(:note) { create(:note_on_commit, commit_id: '12345678', author: user, project: project) }

      it 'allows to read' do
        expect(policy).to be_allowed(:read_note)
        expect(policy).to be_disallowed(:admin_note)
        expect(policy).to be_disallowed(:resolve_note)
        expect(policy).to be_disallowed(:award_emoji)
      end
    end

    context 'when the noteable is a commit' do
      let(:commit) { project.repository.head_commit }
      let(:note) { create(:note_on_commit, commit_id: commit.id, author: user, project: project) }

      context 'when the project is private' do
        let(:project) { create(:project, :private, :repository) }

        it_behaves_like 'a discussion with a private noteable'
      end

      context 'when the project is public' do
        context 'when repository access level is private' do
          let(:project) { create(:project, :public, :repository, :repository_private) }

          it_behaves_like 'a discussion with a private noteable'
        end
      end
    end

    context 'when the noteable is a personal snippet' do
      let(:noteable) { create(:personal_snippet, :public) }
      let(:note) { create(:note, noteable: noteable, author: user) }

      it 'can edit note' do
        expect(policy).to be_allowed(:admin_note)
        expect(policy).to be_allowed(:resolve_note)
        expect(policy).to be_allowed(:read_note)
      end

      context 'when it is private' do
        let(:noteable) { create(:personal_snippet, :private) }

        it 'can not edit nor read the note' do
          expect(policy).to be_disallowed(:admin_note)
          expect(policy).to be_disallowed(:resolve_note)
          expect(policy).to be_disallowed(:read_note)
        end
      end
    end

    context 'when the project is public' do
      context 'when the note author is not a project member' do
        it 'can edit a note' do
          expect(policy).to be_allowed(:admin_note)
          expect(policy).to be_allowed(:resolve_note)
          expect(policy).to be_allowed(:read_note)
        end
      end

      context 'when the noteable is a project snippet' do
        let(:noteable) { create(:project_snippet, :public, project: project) }

        it 'can edit note' do
          expect(policy).to be_allowed(:admin_note)
          expect(policy).to be_allowed(:resolve_note)
          expect(policy).to be_allowed(:read_note)
        end

        context 'when it is private' do
          let(:noteable) { create(:project_snippet, :private, project: project) }

          it_behaves_like 'a discussion with a private noteable'
        end
      end

      context 'when a discussion is confidential' do
        before do
          issue.update_attribute(:confidential, true)
        end

        it_behaves_like 'a discussion with a private noteable'
      end

      context 'when a discussion is locked' do
        before do
          issue.update_attribute(:discussion_locked, true)
        end

        context 'when the note author is a project member' do
          before do
            project.add_developer(user)
          end

          it 'can edit a note' do
            expect(policy).to be_allowed(:admin_note)
            expect(policy).to be_allowed(:resolve_note)
            expect(policy).to be_allowed(:read_note)
          end
        end

        context 'when the note author is not a project member' do
          it 'can not edit a note' do
            expect(policy).to be_disallowed(:admin_note)
            expect(policy).to be_disallowed(:resolve_note)
          end

          it 'can read a note' do
            expect(policy).to be_allowed(:read_note)
          end
        end
      end

      context 'for discussions' do
        let(:policy) { described_class.new(user, note.discussion) }

        it 'allows the author to manage the discussion' do
          expect(policy).to be_allowed(:admin_note)
          expect(policy).to be_allowed(:resolve_note)
          expect(policy).to be_allowed(:read_note)
          expect(policy).to be_allowed(:award_emoji)
        end

        context 'when the user does not have access to the noteable' do
          before do
            noteable.update_attribute(:confidential, true)
          end

          it_behaves_like 'a discussion with a private noteable'
        end
      end

      context 'when it is a system note' do
        let(:developer) { create(:user) }
        let(:any_user) { create(:user) }

        shared_examples_for 'user can read the note' do
          it 'allows the user to read the note' do
            expect(policy).to be_allowed(:read_note)
          end
        end

        shared_examples_for 'user can act on the note' do
          it 'allows the user to read the note' do
            expect(policy).not_to be_allowed(:admin_note)
            expect(policy).to be_allowed(:resolve_note)
            expect(policy).to be_allowed(:award_emoji)
          end
        end

        shared_examples_for 'user cannot read or act on the note' do
          it 'allows user to read the note' do
            expect(policy).not_to be_allowed(:admin_note)
            expect(policy).not_to be_allowed(:resolve_note)
            expect(policy).not_to be_allowed(:read_note)
            expect(policy).not_to be_allowed(:award_emoji)
          end
        end

        context 'when noteable is a public issue' do
          let(:note) { create(:note, system: true, noteable: noteable, author: user, project: project) }

          before do
            project.add_developer(developer)
          end

          context 'when user is project member' do
            let(:policy) { described_class.new(developer, note) }

            it_behaves_like 'user can read the note'
            it_behaves_like 'user can act on the note'
          end

          context 'when user is not project member' do
            let(:policy) { described_class.new(any_user, note) }

            it_behaves_like 'user can read the note'
          end

          context 'when user is anonymous' do
            let(:policy) { described_class.new(nil, note) }

            it_behaves_like 'user can read the note'
          end
        end

        context 'when it is a system note referencing a confidential issue' do
          let(:confidential_issue) { create(:issue, :confidential, project: project) }
          let(:note) { create(:note, system: true, noteable: issue, author: user, project: project, note: "mentioned in issue #{confidential_issue.to_reference(project)}") }

          before do
            project.add_developer(developer)
          end

          context 'when user is project member' do
            let(:policy) { described_class.new(developer, note) }

            it_behaves_like 'user can read the note'
            it_behaves_like 'user can act on the note'
          end

          context 'when user is not project member' do
            let(:policy) { described_class.new(any_user, note) }

            it_behaves_like 'user cannot read or act on the note'
          end

          context 'when user is anonymous' do
            let(:policy) { described_class.new(nil, note) }

            it_behaves_like 'user cannot read or act on the note'
          end
        end
      end

      context 'with confidential notes' do
        def permissions(user, note)
          described_class.new(user, note)
        end

        let(:reporter) { create(:user) }
        let(:developer) { create(:user) }
        let(:maintainer) { create(:user) }
        let(:guest) { create(:user) }
        let(:non_member) { create(:user) }
        let(:author) { create(:user) }
        let(:assignee) { create(:user) }

        before do
          project.add_reporter(reporter)
          project.add_developer(developer)
          project.add_maintainer(maintainer)
          project.add_guest(guest)
        end

        shared_examples_for 'confidential notes permissions' do
          it 'does not allow non members to read confidential notes and replies' do
            expect(permissions(non_member, confidential_note)).to be_disallowed(:read_note, :admin_note, :resolve_note, :award_emoji)
          end

          it 'does not allow guests to read confidential notes and replies' do
            expect(permissions(guest, confidential_note)).to be_disallowed(:read_note, :admin_note, :resolve_note, :award_emoji)
          end

          it 'allows reporter to read all notes but not resolve and admin them' do
            expect(permissions(reporter, confidential_note)).to be_allowed(:read_note, :award_emoji)
            expect(permissions(reporter, confidential_note)).to be_disallowed(:admin_note, :resolve_note)
          end

          it 'allows developer to read and resolve all notes' do
            expect(permissions(developer, confidential_note)).to be_allowed(:read_note, :award_emoji, :resolve_note)
            expect(permissions(developer, confidential_note)).to be_disallowed(:admin_note)
          end

          it 'allows maintainers to read all notes and admin them' do
            expect(permissions(maintainer, confidential_note)).to be_allowed(:read_note, :admin_note, :resolve_note, :award_emoji)
          end

          it 'allows noteable author to read and resolve all notes' do
            expect(permissions(author, confidential_note)).to be_allowed(:read_note, :resolve_note, :award_emoji)
            expect(permissions(author, confidential_note)).to be_disallowed(:admin_note)
          end
        end

        context 'for issues' do
          let(:issue) { create(:issue, project: project, author: author, assignees: [assignee]) }
          let(:confidential_note) { create(:note, :confidential, project: project, noteable: issue) }

          it_behaves_like 'confidential notes permissions'

          it 'allows noteable assignees to read all notes' do
            expect(permissions(assignee, confidential_note)).to be_allowed(:read_note, :award_emoji)
            expect(permissions(assignee, confidential_note)).to be_disallowed(:admin_note, :resolve_note)
          end
        end

        context 'for merge requests' do
          let(:merge_request) { create(:merge_request, source_project: project, author: author, assignees: [assignee]) }
          let(:confidential_note) { create(:note, :confidential, project: project, noteable: merge_request) }

          it_behaves_like 'confidential notes permissions'

          it 'allows noteable assignees to read all notes' do
            expect(permissions(assignee, confidential_note)).to be_allowed(:read_note, :award_emoji)
            expect(permissions(assignee, confidential_note)).to be_disallowed(:admin_note, :resolve_note)
          end
        end

        context 'for project snippets' do
          let(:project_snippet) { create(:project_snippet, project: project, author: author) }
          let(:confidential_note) { create(:note, :confidential, project: project, noteable: project_snippet) }

          it_behaves_like 'confidential notes permissions'
        end

        context 'for personal snippets' do
          let(:personal_snippet) { create(:personal_snippet, author: author) }
          let(:confidential_note) { create(:note, :confidential, project: nil, noteable: personal_snippet) }

          it 'allows snippet author to read and resolve all notes' do
            expect(permissions(author, confidential_note)).to be_allowed(:read_note, :resolve_note, :award_emoji)
            expect(permissions(author, confidential_note)).to be_disallowed(:admin_note)
          end

          it 'does not allow maintainers to read confidential notes and replies' do
            expect(permissions(maintainer, confidential_note)).to be_disallowed(:read_note, :admin_note, :resolve_note, :award_emoji)
          end
        end
      end
    end
  end
end
