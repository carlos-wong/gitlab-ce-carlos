# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::GitalyClient::CommitService do
  let_it_be(:project) { create(:project, :repository) }

  let(:storage_name) { project.repository_storage }
  let(:relative_path) { project.disk_path + '.git' }
  let(:repository) { project.repository }
  let(:repository_message) { repository.gitaly_repository }
  let(:revision) { '913c66a37b4a45b9769037c55c2d238bd0942d2e' }
  let(:commit) { project.commit(revision) }
  let(:client) { described_class.new(repository) }

  describe '#diff_from_parent' do
    context 'when a commit has a parent' do
      it 'sends an RPC request with the parent ID as left commit' do
        request = Gitaly::CommitDiffRequest.new(
          repository: repository_message,
          left_commit_id: 'cfe32cf61b73a0d5e9f13e774abde7ff789b1660',
          right_commit_id: commit.id,
          collapse_diffs: false,
          enforce_limits: true,
          # Tests limitation parameters explicitly
          max_files: 100,
          max_lines: 5000,
          max_bytes: 512000,
          safe_max_files: 100,
          safe_max_lines: 5000,
          safe_max_bytes: 512000,
          max_patch_bytes: 204800
        )

        expect_any_instance_of(Gitaly::DiffService::Stub).to receive(:commit_diff).with(request, kind_of(Hash))

        client.diff_from_parent(commit)
      end
    end

    context 'when a commit does not have a parent' do
      it 'sends an RPC request with empty tree ref as left commit' do
        initial_commit = project.commit('1a0b36b3cdad1d2ee32457c102a8c0b7056fa863').raw
        request        = Gitaly::CommitDiffRequest.new(
          repository: repository_message,
          left_commit_id: Gitlab::Git::EMPTY_TREE_ID,
          right_commit_id: initial_commit.id,
          collapse_diffs: false,
          enforce_limits: true,
          # Tests limitation parameters explicitly
          max_files: 100,
          max_lines: 5000,
          max_bytes: 512000,
          safe_max_files: 100,
          safe_max_lines: 5000,
          safe_max_bytes: 512000,
          max_patch_bytes: 204800
        )

        expect_any_instance_of(Gitaly::DiffService::Stub).to receive(:commit_diff).with(request, kind_of(Hash))

        client.diff_from_parent(initial_commit)
      end
    end

    it 'returns a Gitlab::GitalyClient::DiffStitcher' do
      ret = client.diff_from_parent(commit)

      expect(ret).to be_kind_of(Gitlab::GitalyClient::DiffStitcher)
    end

    it 'encodes paths correctly' do
      expect { client.diff_from_parent(commit, paths: ['encoding/test.txt', 'encoding/テスト.txt', nil]) }.not_to raise_error
    end
  end

  describe '#commit_deltas' do
    context 'when a commit has a parent' do
      it 'sends an RPC request with the parent ID as left commit' do
        request = Gitaly::CommitDeltaRequest.new(
          repository: repository_message,
          left_commit_id: 'cfe32cf61b73a0d5e9f13e774abde7ff789b1660',
          right_commit_id: commit.id
        )

        expect_any_instance_of(Gitaly::DiffService::Stub).to receive(:commit_delta).with(request, kind_of(Hash)).and_return([])

        client.commit_deltas(commit)
      end
    end

    context 'when a commit does not have a parent' do
      it 'sends an RPC request with empty tree ref as left commit' do
        initial_commit = project.commit('1a0b36b3cdad1d2ee32457c102a8c0b7056fa863')
        request        = Gitaly::CommitDeltaRequest.new(
          repository: repository_message,
          left_commit_id: Gitlab::Git::EMPTY_TREE_ID,
          right_commit_id: initial_commit.id
        )

        expect_any_instance_of(Gitaly::DiffService::Stub).to receive(:commit_delta).with(request, kind_of(Hash)).and_return([])

        client.commit_deltas(initial_commit)
      end
    end
  end

  describe '#diff_stats' do
    let(:left_commit_id) { 'master' }
    let(:right_commit_id) { 'cfe32cf61b73a0d5e9f13e774abde7ff789b1660' }

    it 'sends an RPC request and returns the stats' do
      request = Gitaly::DiffStatsRequest.new(repository: repository_message,
                                             left_commit_id: left_commit_id,
                                             right_commit_id: right_commit_id)

      diff_stat_response = Gitaly::DiffStatsResponse.new(
        stats: [{ additions: 1, deletions: 2, path: 'test' }])

      expect_any_instance_of(Gitaly::DiffService::Stub).to receive(:diff_stats)
        .with(request, kind_of(Hash)).and_return([diff_stat_response])

      returned_value = described_class.new(repository).diff_stats(left_commit_id, right_commit_id)

      expect(returned_value).to eq(diff_stat_response.stats)
    end
  end

  describe '#find_changed_paths' do
    let(:commits) { %w[1a0b36b3cdad1d2ee32457c102a8c0b7056fa863 cfe32cf61b73a0d5e9f13e774abde7ff789b1660] }

    it 'sends an RPC request and returns the stats' do
      request = Gitaly::FindChangedPathsRequest.new(repository: repository_message,
                                                    commits: commits)

      changed_paths_response = Gitaly::FindChangedPathsResponse.new(
        paths: [{
          path: "app/assets/javascripts/boards/components/project_select.vue",
          status: :MODIFIED
        }])

      expect_any_instance_of(Gitaly::DiffService::Stub).to receive(:find_changed_paths)
        .with(request, kind_of(Hash)).and_return([changed_paths_response])

      returned_value = described_class.new(repository).find_changed_paths(commits)
      mapped_expected_value = changed_paths_response.paths.map { |path| Gitlab::Git::ChangedPath.new(status: path.status, path: path.path) }

      expect(returned_value.as_json).to eq(mapped_expected_value.as_json)
    end
  end

  describe '#tree_entries' do
    subject { client.tree_entries(repository, revision, path, recursive, pagination_params) }

    let(:path) { '/' }
    let(:recursive) { false }
    let(:pagination_params) { nil }

    it 'sends a get_tree_entries message' do
      expect_any_instance_of(Gitaly::CommitService::Stub)
        .to receive(:get_tree_entries)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return([])

      is_expected.to eq([[], nil])
    end

    context 'with UTF-8 params strings' do
      let(:revision) { "branch\u011F" }
      let(:path) { "foo/\u011F.txt" }

      it 'handles string encodings correctly' do
        expect_any_instance_of(Gitaly::CommitService::Stub)
          .to receive(:get_tree_entries)
          .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
          .and_return([])

        is_expected.to eq([[], nil])
      end
    end

    context 'with pagination parameters' do
      let(:pagination_params) { { limit: 3, page_token: nil } }

      it 'responds with a pagination cursor' do
        pagination_cursor = Gitaly::PaginationCursor.new(next_cursor: 'aabbccdd')
        response = Gitaly::GetTreeEntriesResponse.new(
          entries: [],
          pagination_cursor: pagination_cursor
        )

        expect_any_instance_of(Gitaly::CommitService::Stub)
          .to receive(:get_tree_entries)
          .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
          .and_return([response])

        is_expected.to eq([[], pagination_cursor])
      end
    end
  end

  describe '#commit_count' do
    before do
      expect_any_instance_of(Gitaly::CommitService::Stub)
        .to receive(:count_commits)
        .with(gitaly_request_with_path(storage_name, relative_path),
              kind_of(Hash))
        .and_return([])
    end

    it 'sends a commit_count message' do
      client.commit_count(revision)
    end

    context 'with UTF-8 params strings' do
      let(:revision) { "branch\u011F" }
      let(:path) { "foo/\u011F.txt" }

      it 'handles string encodings correctly' do
        client.commit_count(revision, path: path)
      end
    end
  end

  describe '#find_commit' do
    let(:revision) { Gitlab::Git::EMPTY_TREE_ID }

    it 'sends an RPC request' do
      request = Gitaly::FindCommitRequest.new(
        repository: repository_message, revision: revision
      )

      expect_any_instance_of(Gitaly::CommitService::Stub).to receive(:find_commit)
        .with(request, kind_of(Hash)).and_return(double(commit: nil))

      described_class.new(repository).find_commit(revision)
    end

    describe 'caching', :request_store do
      let(:commit_dbl) { double(id: 'f01b' * 10) }

      context 'when passed revision is a branch name' do
        it 'calls Gitaly' do
          expect_any_instance_of(Gitaly::CommitService::Stub).to receive(:find_commit).twice.and_return(double(commit: commit_dbl))

          commit = nil
          2.times { commit = described_class.new(repository).find_commit('master') }

          expect(commit).to eq(commit_dbl)
        end
      end

      context 'when passed revision is a commit ID' do
        it 'returns a cached commit' do
          expect_any_instance_of(Gitaly::CommitService::Stub).to receive(:find_commit).once.and_return(double(commit: commit_dbl))

          commit = nil
          2.times { commit = described_class.new(repository).find_commit('f01b' * 10) }

          expect(commit).to eq(commit_dbl)
        end
      end

      context 'when caching of the ref name is enabled' do
        it 'caches negative entries' do
          expect_any_instance_of(Gitaly::CommitService::Stub).to receive(:find_commit).once.and_return(double(commit: nil))

          commit = nil
          2.times do
            ::Gitlab::GitalyClient.allow_ref_name_caching do
              commit = described_class.new(repository).find_commit('master')
            end
          end

          expect(commit).to eq(nil)
        end

        it 'returns a cached commit' do
          expect_any_instance_of(Gitaly::CommitService::Stub).to receive(:find_commit).once.and_return(double(commit: commit_dbl))

          commit = nil
          2.times do
            ::Gitlab::GitalyClient.allow_ref_name_caching do
              commit = described_class.new(repository).find_commit('master')
            end
          end

          expect(commit).to eq(commit_dbl)
        end
      end
    end
  end

  describe '#list_commits' do
    let(:revisions) { 'master' }
    let(:reverse) { false }
    let(:pagination_params) { nil }

    shared_examples 'a ListCommits request' do
      before do
        ::Gitlab::GitalyClient.clear_stubs!
      end

      it 'sends a list_commits message' do
        expect_next_instance_of(Gitaly::CommitService::Stub) do |service|
          expected_request = gitaly_request_with_params(
            Array.wrap(revisions),
            reverse: reverse,
            pagination_params: pagination_params
          )

          expect(service).to receive(:list_commits).with(expected_request, kind_of(Hash)).and_return([])
        end

        client.list_commits(revisions, reverse: reverse, pagination_params: pagination_params)
      end
    end

    it_behaves_like 'a ListCommits request'

    context 'with multiple revisions' do
      let(:revisions) { %w[master --not --all] }

      it_behaves_like 'a ListCommits request'
    end

    context 'with reverse: true' do
      let(:reverse) { true }

      it_behaves_like 'a ListCommits request'
    end

    context 'with pagination params' do
      let(:pagination_params) { { limit: 1, page_token: 'foo' } }

      it_behaves_like 'a ListCommits request'
    end
  end

  describe '#list_new_commits' do
    let(:revisions) { [revision] }
    let(:gitaly_commits) { create_list(:gitaly_commit, 3) }
    let(:expected_commits) { gitaly_commits.map { |c| Gitlab::Git::Commit.new(repository, c) }}

    subject do
      client.list_new_commits(revisions)
    end

    shared_examples 'a #list_all_commits message' do
      it 'sends a list_all_commits message' do
        expected_repository = repository.gitaly_repository.dup
        expected_repository.git_alternate_object_directories = Google::Protobuf::RepeatedField.new(:string)

        expect_next_instance_of(Gitaly::CommitService::Stub) do |service|
          expect(service).to receive(:list_all_commits)
            .with(gitaly_request_with_params(repository: expected_repository), kind_of(Hash))
            .and_return([Gitaly::ListAllCommitsResponse.new(commits: gitaly_commits)])

          # The object directory of the repository must not be set so that we
          # don't use the quarantine directory.
          objects_exist_repo = repository.gitaly_repository.dup
          objects_exist_repo.git_object_directory = ""

          # The first request contains the repository, the second request the
          # commit IDs we want to check for existence.
          objects_exist_request = [
            gitaly_request_with_params(repository: objects_exist_repo),
            gitaly_request_with_params(revisions: gitaly_commits.map(&:id))
          ]

          objects_exist_response = Gitaly::CheckObjectsExistResponse.new(revisions: revision_existence.map do
            |rev, exists| Gitaly::CheckObjectsExistResponse::RevisionExistence.new(name: rev, exists: exists)
          end)

          expect(service).to receive(:check_objects_exist)
            .with(objects_exist_request, kind_of(Hash))
            .and_return([objects_exist_response])
        end

        expect(subject).to eq(expected_commits)
      end
    end

    shared_examples 'a #list_commits message' do
      it 'sends a list_commits message' do
        expect_next_instance_of(Gitaly::CommitService::Stub) do |service|
          expect(service).to receive(:list_commits)
            .with(gitaly_request_with_params(revisions: revisions + %w[--not --all]), kind_of(Hash))
            .and_return([Gitaly::ListCommitsResponse.new(commits: gitaly_commits)])
        end

        expect(subject).to eq(expected_commits)
      end
    end

    before do
      ::Gitlab::GitalyClient.clear_stubs!

      allow(Gitlab::Git::HookEnv)
        .to receive(:all)
        .with(repository.gl_repository)
        .and_return(git_env)
    end

    context 'with hook environment' do
      let(:git_env) do
        {
          'GIT_OBJECT_DIRECTORY_RELATIVE' => '.git/objects',
          'GIT_ALTERNATE_OBJECT_DIRECTORIES_RELATIVE' => ['/dir/one', '/dir/two']
        }
      end

      context 'reject commits which exist in target repository' do
        let(:revision_existence) { gitaly_commits.to_h { |c| [c.id, true] } }
        let(:expected_commits) { [] }

        it_behaves_like 'a #list_all_commits message'
      end

      context 'keep commits which do not exist in target repository' do
        let(:revision_existence) { gitaly_commits.to_h { |c| [c.id, false] } }

        it_behaves_like 'a #list_all_commits message'
      end

      context 'mixed existing and nonexisting commits' do
        let(:revision_existence) do
          {
            gitaly_commits[0].id => true,
            gitaly_commits[1].id => false,
            gitaly_commits[2].id => true
          }
        end

        let(:expected_commits) { [Gitlab::Git::Commit.new(repository, gitaly_commits[1])] }

        it_behaves_like 'a #list_all_commits message'
      end
    end

    context 'without hook environment' do
      let(:git_env) do
        {
          'GIT_OBJECT_DIRECTORY_RELATIVE' => '',
          'GIT_ALTERNATE_OBJECT_DIRECTORIES_RELATIVE' => []
        }
      end

      it_behaves_like 'a #list_commits message'
    end
  end

  describe '#commit_stats' do
    let(:request) do
      Gitaly::CommitStatsRequest.new(
        repository: repository_message, revision: revision
      )
    end

    let(:response) do
      Gitaly::CommitStatsResponse.new(
        oid: revision,
        additions: 11,
        deletions: 15
      )
    end

    subject { described_class.new(repository).commit_stats(revision) }

    it 'sends an RPC request' do
      expect_any_instance_of(Gitaly::CommitService::Stub).to receive(:commit_stats)
        .with(request, kind_of(Hash)).and_return(response)

      expect(subject.additions).to eq(11)
      expect(subject.deletions).to eq(15)
    end
  end

  describe '#find_commits' do
    it 'sends an RPC request with NONE when default' do
      request = Gitaly::FindCommitsRequest.new(
        repository: repository_message,
        disable_walk: true,
        order: 'NONE',
        global_options: Gitaly::GlobalOptions.new(literal_pathspecs: false)
      )

      expect_any_instance_of(Gitaly::CommitService::Stub).to receive(:find_commits)
        .with(request, kind_of(Hash)).and_return([])

      client.find_commits(order: 'default')
    end

    it 'sends an RPC request' do
      request = Gitaly::FindCommitsRequest.new(
        repository: repository_message,
        disable_walk: true,
        order: 'TOPO',
        global_options: Gitaly::GlobalOptions.new(literal_pathspecs: false)
      )

      expect_any_instance_of(Gitaly::CommitService::Stub).to receive(:find_commits)
        .with(request, kind_of(Hash)).and_return([])

      client.find_commits(order: 'topo')
    end

    it 'sends an RPC request with an author' do
      request = Gitaly::FindCommitsRequest.new(
        repository: repository_message,
        disable_walk: true,
        order: 'NONE',
        author: "Billy Baggins <bilbo@shire.com>",
        global_options: Gitaly::GlobalOptions.new(literal_pathspecs: false)
      )

      expect_any_instance_of(Gitaly::CommitService::Stub).to receive(:find_commits)
        .with(request, kind_of(Hash)).and_return([])

      client.find_commits(order: 'default', author: "Billy Baggins <bilbo@shire.com>")
    end
  end

  describe '#object_existence_map' do
    shared_examples 'a CheckObjectsExistRequest' do
      before do
        ::Gitlab::GitalyClient.clear_stubs!
      end

      it 'returns expected results' do
        expect_next_instance_of(Gitaly::CommitService::Stub) do |service|
          expect(service)
            .to receive(:check_objects_exist)
            .and_call_original
        end

        expect(client.object_existence_map(revisions.keys)).to eq(revisions)
      end
    end

    context 'with empty request' do
      let(:revisions) { {} }

      it_behaves_like 'a CheckObjectsExistRequest'
    end

    context 'when revision exists' do
      let(:revisions) { { 'refs/heads/master' => true } }

      it_behaves_like 'a CheckObjectsExistRequest'
    end

    context 'when revision does not exist' do
      let(:revisions) { { 'refs/does/not/exist' => false } }

      it_behaves_like 'a CheckObjectsExistRequest'
    end

    context 'when request contains mixed revisions' do
      let(:revisions) do
        {
          "refs/heads/master" => true,
          "refs/does/not/exist" => false
        }
      end

      it_behaves_like 'a CheckObjectsExistRequest'
    end

    context 'when requesting many revisions' do
      let(:revisions) do
        Array(1..1234).to_h { |i| ["refs/heads/#{i}", false] }
      end

      it_behaves_like 'a CheckObjectsExistRequest'
    end
  end

  describe '#commits_by_message' do
    shared_examples 'a CommitsByMessageRequest' do
      let(:commits) { create_list(:gitaly_commit, 2) }

      before do
        request = Gitaly::CommitsByMessageRequest.new(
          repository: repository_message,
          query: query,
          revision: (options[:revision] || '').dup.force_encoding(Encoding::ASCII_8BIT),
          path: (options[:path] || '').dup.force_encoding(Encoding::ASCII_8BIT),
          limit: (options[:limit] || 1000).to_i,
          offset: (options[:offset] || 0).to_i,
          global_options: Gitaly::GlobalOptions.new(literal_pathspecs: true)
        )

        allow_any_instance_of(Gitaly::CommitService::Stub)
          .to receive(:commits_by_message)
          .with(request, kind_of(Hash))
          .and_return([Gitaly::CommitsByMessageResponse.new(commits: commits)])
      end

      it 'sends an RPC request with the correct payload' do
        expect(client.commits_by_message(query, **options)).to match_array(wrap_commits(commits))
      end
    end

    let(:query) { 'Add a feature' }
    let(:options) { {} }

    context 'when only the query is provided' do
      include_examples 'a CommitsByMessageRequest'
    end

    context 'when all arguments are provided' do
      let(:options) { { revision: 'feature-branch', path: 'foo.txt', limit: 10, offset: 20 } }

      include_examples 'a CommitsByMessageRequest'
    end

    context 'when limit and offset are not integers' do
      let(:options) { { limit: '10', offset: '60' } }

      include_examples 'a CommitsByMessageRequest'
    end

    context 'when revision and path contain non-ASCII characters' do
      let(:options) { { revision: "branch\u011F", path: "foo/\u011F.txt" } }

      include_examples 'a CommitsByMessageRequest'
    end

    def wrap_commits(commits)
      commits.map { |commit| Gitlab::Git::Commit.new(repository, commit) }
    end
  end

  describe '#list_commits_by_ref_name' do
    let(:project) { create(:project, :repository, create_branch: 'ü/unicode/multi-byte') }

    it 'lists latest commits grouped by a ref name' do
      response = client.list_commits_by_ref_name(%w[master feature v1.0.0 nonexistent ü/unicode/multi-byte])

      expect(response.keys.count).to eq 4
      expect(response.fetch('master').id).to eq 'b83d6e391c22777fca1ed3012fce84f633d7fed0'
      expect(response.fetch('feature').id).to eq '0b4bc9a49b562e85de7cc9e834518ea6828729b9'
      expect(response.fetch('v1.0.0').id).to eq '6f6d7e7ed97bb5f0054f2b1df789b39ca89b6ff9'
      expect(response.fetch('ü/unicode/multi-byte')).to be_present
      expect(response).not_to have_key 'nonexistent'
    end
  end

  describe '#raw_blame' do
    let(:project) { create(:project, :test_repo) }
    let(:revision) { 'blame-on-renamed' }
    let(:path) { 'files/plain_text/renamed' }

    let(:blame_headers) do
      [
        '405a45736a75e439bb059e638afaa9a3c2eeda79 1 1 2',
        '405a45736a75e439bb059e638afaa9a3c2eeda79 2 2',
        'bed1d1610ebab382830ee888288bf939c43873bb 3 3 1',
        '3685515c40444faf92774e72835e1f9c0e809672 4 4 1',
        '32c33da59f8a1a9f90bdeda570337888b00b244d 5 5 1'
      ]
    end

    subject(:blame) { client.raw_blame(revision, path, range: range).split("\n") }

    context 'without a range' do
      let(:range) { nil }

      it 'blames a whole file' do
        is_expected.to include(*blame_headers)
      end
    end

    context 'with a range' do
      let(:range) { '3,4' }

      it 'blames part of a file' do
        is_expected.to include(blame_headers[2], blame_headers[3])
        is_expected.not_to include(blame_headers[0], blame_headers[1], blame_headers[4])
      end
    end
  end
end
