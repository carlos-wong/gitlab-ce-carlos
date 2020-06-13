# frozen_string_literal: true

require 'spec_helper'

describe SnippetRepository do
  let_it_be(:user) { create(:user) }
  let(:snippet) { create(:personal_snippet, :repository, author: user) }
  let(:snippet_repository) { snippet.snippet_repository }
  let(:commit_opts) { { branch_name: 'master', message: 'whatever' } }

  describe 'associations' do
    it { is_expected.to belong_to(:shard) }
    it { is_expected.to belong_to(:snippet) }
  end

  describe '.find_snippet' do
    it 'finds snippet by disk path' do
      snippet = create(:snippet, author: user)
      snippet.track_snippet_repository

      expect(described_class.find_snippet(snippet.disk_path)).to eq(snippet)
    end

    it 'returns nil when it does not find the snippet' do
      expect(described_class.find_snippet('@@unexisting/path/to/snippet')).to be_nil
    end
  end

  describe '#multi_files_action' do
    let(:new_file) { { file_path: 'new_file_test', content: 'bar' } }
    let(:move_file) { { previous_path: 'CHANGELOG', file_path: 'CHANGELOG_new', content: 'bar' } }
    let(:update_file) { { previous_path: 'README', file_path: 'README', content: 'bar' } }
    let(:data) { [new_file, move_file, update_file] }

    it 'returns nil when files argument is empty' do
      expect(snippet.repository).not_to receive(:multi_action)

      operation = snippet_repository.multi_files_action(user, [], commit_opts)

      expect(operation).to be_nil
    end

    it 'returns nil when files argument is nil' do
      expect(snippet.repository).not_to receive(:multi_action)

      operation = snippet_repository.multi_files_action(user, nil, commit_opts)

      expect(operation).to be_nil
    end

    it 'performs the operation accordingly to the files data' do
      new_file_blob = blob_at(snippet, new_file[:file_path])
      move_file_blob = blob_at(snippet, move_file[:previous_path])
      update_file_blob = blob_at(snippet, update_file[:previous_path])

      aggregate_failures do
        expect(new_file_blob).to be_nil
        expect(move_file_blob).not_to be_nil
        expect(update_file_blob).not_to be_nil
      end

      expect do
        snippet_repository.multi_files_action(user, data, commit_opts)
      end.not_to raise_error

      aggregate_failures do
        data.each do |entry|
          blob = blob_at(snippet, entry[:file_path])

          expect(blob).not_to be_nil
          expect(blob.path).to eq entry[:file_path]
          expect(blob.data).to eq entry[:content]
        end
      end
    end

    it 'tries to obtain an exclusive lease' do
      expect(Gitlab::ExclusiveLease).to receive(:new).with("multi_files_action:#{snippet.id}", anything).and_call_original

      snippet_repository.multi_files_action(user, data, commit_opts)
    end

    it 'cancels the lease when the method has finished' do
      expect(Gitlab::ExclusiveLease).to receive(:cancel).with("multi_files_action:#{snippet.id}", anything).and_call_original

      snippet_repository.multi_files_action(user, data, commit_opts)
    end

    it 'raises an error if the lease cannot be obtained' do
      allow_next_instance_of(Gitlab::ExclusiveLease) do |instance|
        allow(instance).to receive(:try_obtain).and_return false
      end

      expect do
        snippet_repository.multi_files_action(user, data, commit_opts)
      end.to raise_error(described_class::CommitError)
    end

    context 'with commit actions' do
      let(:result) do
        [{ action: :create }.merge(new_file),
         { action: :move }.merge(move_file),
         { action: :update }.merge(update_file)]
      end
      let(:repo) { double }

      before do
        allow(snippet).to receive(:repository).and_return(repo)
        allow(repo).to receive(:ls_files).and_return([])
      end

      it 'infers the commit action based on the parameters if not present' do
        expect(repo).to receive(:multi_action).with(user, hash_including(actions: result))

        snippet_repository.multi_files_action(user, data, commit_opts)
      end

      context 'when commit actions are present' do
        let(:file_action) { { file_path: 'foo.txt', content: 'foo', action: :foobar } }
        let(:data) { [file_action] }

        it 'does not change commit action' do
          expect(repo).to(
            receive(:multi_action).with(
              user,
              hash_including(actions: array_including(hash_including(action: :foobar)))))

          snippet_repository.multi_files_action(user, data, commit_opts)
        end
      end
    end

    shared_examples 'snippet repository with file names' do |*filenames|
      it 'sets a name for unnamed files' do
        ls_files = snippet.repository.ls_files(nil)
        expect(ls_files).to include(*filenames)
      end
    end

    let_it_be(:named_snippet) { { file_path: 'fee.txt', content: 'bar', action: :create } }
    let_it_be(:unnamed_snippet) { { file_path: '', content: 'dummy', action: :create } }

    context 'when some files are not named' do
      let(:data) { [named_snippet] + Array.new(2) { unnamed_snippet.clone } }

      before do
        expect do
          snippet_repository.multi_files_action(user, data, commit_opts)
        end.not_to raise_error
      end

      it_behaves_like 'snippet repository with file names', 'snippetfile1.txt', 'snippetfile2.txt'
    end

    context 'repository already has 10 unnamed snippets' do
      let(:pre_populate_data) { Array.new(10) { unnamed_snippet.clone } }
      let(:data) { [named_snippet] + Array.new(2) { unnamed_snippet.clone } }

      before do
        # Pre-populate repository with 9 unnamed snippets.
        snippet_repository.multi_files_action(user, pre_populate_data, commit_opts)

        expect do
          snippet_repository.multi_files_action(user, data, commit_opts)
        end.not_to raise_error
      end

      it_behaves_like 'snippet repository with file names', 'snippetfile10.txt', 'snippetfile11.txt'
    end
  end

  def blob_at(snippet, path)
    snippet.repository.blob_at('master', path)
  end

  def first_blob(snippet)
    snippet.repository.blob_at('master', snippet.repository.ls_files(nil).first)
  end
end
