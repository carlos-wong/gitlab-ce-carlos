# frozen_string_literal: true

require 'spec_helper'

describe Snippets::DestroyService do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:other_user) { create(:user) }

  describe '#execute' do
    subject { described_class.new(user, snippet).execute }

    context 'when snippet is nil' do
      let(:snippet) { nil }

      it 'returns a ServiceResponse error' do
        expect(subject).to be_error
      end
    end

    shared_examples 'a successful destroy' do
      it 'deletes the snippet' do
        expect { subject }.to change { Snippet.count }.by(-1)
      end

      it 'returns ServiceResponse success' do
        expect(subject).to be_success
      end
    end

    shared_examples 'an unsuccessful destroy' do
      it 'does not delete the snippet' do
        expect { subject }.not_to change { Snippet.count }
      end

      it 'returns ServiceResponse error' do
        expect(subject).to be_error
      end
    end

    shared_examples 'deletes the snippet repository' do
      it 'removes the snippet repository' do
        expect(snippet.repository.exists?).to be_truthy
        expect(GitlabShellWorker).to receive(:perform_in)
        expect_next_instance_of(Repositories::DestroyService) do |instance|
          expect(instance).to receive(:execute).and_call_original
        end

        expect(subject).to be_success
      end

      context 'when the repository deletion service raises an error' do
        before do
          allow_next_instance_of(Repositories::DestroyService) do |instance|
            allow(instance).to receive(:execute).and_return({ status: :error })
          end
        end

        it_behaves_like 'an unsuccessful destroy'

        it 'does not try to rollback repository' do
          expect(Repositories::DestroyRollbackService).not_to receive(:new)

          subject
        end
      end

      context 'when a destroy error is raised' do
        before do
          allow(snippet).to receive(:destroy!).and_raise(ActiveRecord::ActiveRecordError)
        end

        it_behaves_like 'an unsuccessful destroy'

        it 'attempts to rollback the repository' do
          expect(Repositories::DestroyRollbackService).to receive(:new).and_call_original

          subject
        end
      end

      context 'when repository is nil' do
        it 'does not schedule anything and return success' do
          allow(snippet).to receive(:repository).and_return(nil)

          expect(GitlabShellWorker).not_to receive(:perform_in)
          expect_next_instance_of(Repositories::DestroyService) do |instance|
            expect(instance).to receive(:execute).and_call_original
          end

          expect(subject).to be_success
        end
      end
    end

    context 'when ProjectSnippet' do
      let!(:snippet) { create(:project_snippet, :repository, project: project, author: author) }

      context 'when user is able to admin_project_snippet' do
        let(:author) { user }

        before do
          project.add_developer(user)
        end

        it_behaves_like 'a successful destroy'
        it_behaves_like 'deletes the snippet repository'
      end

      context 'when user is not able to admin_project_snippet' do
        let(:author) { other_user }

        it_behaves_like 'an unsuccessful destroy'
      end
    end

    context 'when PersonalSnippet' do
      let!(:snippet) { create(:personal_snippet, :repository, author: author) }

      context 'when user is able to admin_personal_snippet' do
        let(:author) { user }

        it_behaves_like 'a successful destroy'
        it_behaves_like 'deletes the snippet repository'
      end

      context 'when user is not able to admin_personal_snippet' do
        let(:author) { other_user }

        it_behaves_like 'an unsuccessful destroy'
      end
    end

    context 'when the repository does not exists' do
      let(:snippet) { create(:personal_snippet, author: user) }

      it 'does not schedule anything and return success' do
        expect(snippet.repository).not_to be_nil
        expect(snippet.repository.exists?).to be_falsey

        expect(GitlabShellWorker).not_to receive(:perform_in)
        expect_next_instance_of(Repositories::DestroyService) do |instance|
          expect(instance).to receive(:execute).and_call_original
        end

        expect(subject).to be_success
      end
    end
  end
end
