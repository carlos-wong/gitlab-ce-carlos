# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::GitalyClient::RefService do
  let(:project) { create(:project, :repository) }
  let(:storage_name) { project.repository_storage }
  let(:relative_path) { project.disk_path + '.git' }
  let(:repository) { project.repository }
  let(:client) { described_class.new(repository) }

  describe '#branches' do
    it 'sends a find_all_branches message' do
      expect_any_instance_of(Gitaly::RefService::Stub)
        .to receive(:find_all_branches)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return([])

      client.branches
    end
  end

  describe '#remote_branches' do
    let(:remote_name) { 'my_remote' }

    subject { client.remote_branches(remote_name) }

    it 'sends a find_all_remote_branches message' do
      expect_any_instance_of(Gitaly::RefService::Stub)
        .to receive(:find_all_remote_branches)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return([])

      subject
    end

    it 'concatenates and returns the response branches as Gitlab::Git::Branch objects' do
      target_commits = create_list(:gitaly_commit, 4)
      response_branches = target_commits.each_with_index.map do |gitaly_commit, i|
        Gitaly::Branch.new(name: "#{remote_name}/#{i}", target_commit: gitaly_commit)
      end
      response = [
        Gitaly::FindAllRemoteBranchesResponse.new(branches: response_branches[0, 2]),
        Gitaly::FindAllRemoteBranchesResponse.new(branches: response_branches[2, 2])
      ]

      expect_any_instance_of(Gitaly::RefService::Stub)
        .to receive(:find_all_remote_branches).and_return(response)

      expect(subject.length).to be(response_branches.length)

      response_branches.each_with_index do |gitaly_branch, i|
        branch = subject[i]
        commit = Gitlab::Git::Commit.new(repository, gitaly_branch.target_commit)

        expect(branch.name).to eq(i.to_s) # It removes the `remote/` prefix
        expect(branch.dereferenced_target).to eq(commit)
      end
    end
  end

  describe '#merged_branches' do
    it 'sends a find_all_branches message' do
      expect_any_instance_of(Gitaly::RefService::Stub)
        .to receive(:find_all_branches)
        .with(gitaly_request_with_params(merged_only: true, merged_branches: ['test']), kind_of(Hash))
        .and_return([])

      client.merged_branches(%w(test))
    end
  end

  describe '#branch_names' do
    it 'sends a find_all_branch_names message' do
      expect_any_instance_of(Gitaly::RefService::Stub)
        .to receive(:find_all_branch_names)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return([])

      client.branch_names
    end
  end

  describe '#tag_names' do
    it 'sends a find_all_tag_names message' do
      expect_any_instance_of(Gitaly::RefService::Stub)
        .to receive(:find_all_tag_names)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return([])

      client.tag_names
    end
  end

  describe '#find_branch' do
    it 'sends a find_branch message' do
      expect_any_instance_of(Gitaly::RefService::Stub)
        .to receive(:find_branch)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return(double(branch: Gitaly::Branch.new(name: 'name', target_commit: build(:gitaly_commit))))

      client.find_branch('name')
    end
  end

  describe '#find_tag' do
    it 'sends a find_tag message' do
      expect_any_instance_of(Gitaly::RefService::Stub)
        .to receive(:find_tag)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return(double(tag: Gitaly::Tag.new))

      client.find_tag('name')
    end

    context 'when tag is empty' do
      it 'does not send a fing_tag message' do
        expect_any_instance_of(Gitaly::RefService::Stub).not_to receive(:find_tag)

        expect(client.find_tag('')).to be_nil
      end
    end
  end

  describe '#default_branch_name' do
    it 'sends a find_default_branch_name message' do
      expect_any_instance_of(Gitaly::RefService::Stub)
        .to receive(:find_default_branch_name)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return(double(name: 'foo'))

      client.default_branch_name
    end
  end

  describe '#local_branches' do
    it 'sends a find_local_branches message' do
      expect_any_instance_of(Gitaly::RefService::Stub)
        .to receive(:find_local_branches)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return([])

      client.local_branches
    end

    it 'parses and sends the sort parameter' do
      expect_any_instance_of(Gitaly::RefService::Stub)
        .to receive(:find_local_branches)
        .with(gitaly_request_with_params(sort_by: :UPDATED_DESC), kind_of(Hash))
        .and_return([])

      client.local_branches(sort_by: 'updated_desc')
    end

    it 'translates known mismatches on sort param values' do
      expect_any_instance_of(Gitaly::RefService::Stub)
        .to receive(:find_local_branches)
        .with(gitaly_request_with_params(sort_by: :NAME), kind_of(Hash))
        .and_return([])

      client.local_branches(sort_by: 'name_asc')
    end

    it 'raises an argument error if an invalid sort_by parameter is passed' do
      expect { client.local_branches(sort_by: 'invalid_sort') }.to raise_error(ArgumentError)
    end
  end

  describe '#tags' do
    it 'sends a find_all_tags message' do
      expect_any_instance_of(Gitaly::RefService::Stub)
        .to receive(:find_all_tags)
        .and_return([])

      client.tags
    end

    context 'with sorting option' do
      it 'sends a correct find_all_tags message' do
        expected_sort_by = Gitaly::FindAllTagsRequest::SortBy.new(
          key: :REFNAME,
          direction: :ASCENDING
        )

        expect_any_instance_of(Gitaly::RefService::Stub)
          .to receive(:find_all_tags)
          .with(gitaly_request_with_params(sort_by: expected_sort_by), kind_of(Hash))
          .and_return([])

        client.tags(sort_by: 'name_asc')
      end
    end

    context 'with pagination option' do
      it 'sends a correct find_all_tags message' do
        expected_pagination = Gitaly::PaginationParameter.new(
          limit: 5,
          page_token: 'refs/tags/v1.0.0'
        )

        expect_any_instance_of(Gitaly::RefService::Stub)
          .to receive(:find_all_tags)
          .with(gitaly_request_with_params(pagination_params: expected_pagination), kind_of(Hash))
          .and_return([])

        client.tags(pagination_params: { limit: 5, page_token: 'refs/tags/v1.0.0' })
      end
    end
  end

  describe '#branch_names_contains_sha' do
    it 'sends a list_branch_names_containing_commit message' do
      expect_any_instance_of(Gitaly::RefService::Stub)
        .to receive(:list_branch_names_containing_commit)
        .with(gitaly_request_with_params(commit_id: '123', limit: 0), kind_of(Hash))
        .and_return([])

      client.branch_names_contains_sha('123')
    end
  end

  describe '#get_tag_messages' do
    it 'sends a get_tag_messages message' do
      expect_any_instance_of(Gitaly::RefService::Stub)
        .to receive(:get_tag_messages)
        .with(gitaly_request_with_params(tag_ids: ['some_tag_id']), kind_of(Hash))
        .and_return([])

      client.get_tag_messages(['some_tag_id'])
    end
  end

  describe '#get_tag_signatures' do
    it 'sends a get_tag_signatures message' do
      expect_any_instance_of(Gitaly::RefService::Stub)
        .to receive(:get_tag_signatures)
        .with(gitaly_request_with_params(tag_revisions: ['some_tag_id']), kind_of(Hash))
        .and_return([])

      client.get_tag_signatures(['some_tag_id'])
    end
  end

  describe '#ref_exists?' do
    let(:ref) { 'refs/heads/master' }

    it 'sends a ref_exists message' do
      expect_any_instance_of(Gitaly::RefService::Stub)
        .to receive(:ref_exists)
        .with(gitaly_request_with_params(ref: ref), kind_of(Hash))
        .and_return(double('ref_exists_response', value: true))

      expect(client.ref_exists?(ref)).to be true
    end
  end

  describe '#delete_refs' do
    let(:prefixes) { %w(refs/heads refs/keep-around) }

    subject(:delete_refs) { client.delete_refs(except_with_prefixes: prefixes) }

    it 'sends a delete_refs message' do
      expect_any_instance_of(Gitaly::RefService::Stub)
        .to receive(:delete_refs)
        .with(gitaly_request_with_params(except_with_prefix: prefixes), kind_of(Hash))
        .and_return(double('delete_refs_response', git_error: ""))

      delete_refs
    end

    context 'with a references locked error' do
      let(:references_locked_error) do
        new_detailed_error(
          GRPC::Core::StatusCodes::FAILED_PRECONDITION,
          "error message",
          Gitaly::DeleteRefsError.new(references_locked: Gitaly::ReferencesLockedError.new))
      end

      it 'raises ReferencesLockedError' do
        expect_any_instance_of(Gitaly::RefService::Stub).to receive(:delete_refs)
          .with(gitaly_request_with_params(except_with_prefix: prefixes), kind_of(Hash))
          .and_raise(references_locked_error)

        expect { delete_refs }.to raise_error(Gitlab::Git::ReferencesLockedError)
      end
    end

    context 'with a invalid format error' do
      let(:invalid_refs) {['\invali.\d/1', '\.invali/d/2']}
      let(:invalid_reference_format_error) do
        new_detailed_error(
          GRPC::Core::StatusCodes::INVALID_ARGUMENT,
          "error message",
          Gitaly::DeleteRefsError.new(invalid_format: Gitaly::InvalidRefFormatError.new(refs: invalid_refs)))
      end

      it 'raises InvalidRefFormatError' do
        expect_any_instance_of(Gitaly::RefService::Stub)
          .to receive(:delete_refs)
          .with(gitaly_request_with_params(except_with_prefix: prefixes), kind_of(Hash))
          .and_raise(invalid_reference_format_error)

        expect { delete_refs }.to raise_error do |error|
          expect(error).to be_a(Gitlab::Git::InvalidRefFormatError)
          expect(error.message).to eq("references have an invalid format: #{invalid_refs.join(",")}")
        end
      end
    end
  end

  describe '#list_refs' do
    it 'sends a list_refs message' do
      expect_any_instance_of(Gitaly::RefService::Stub)
        .to receive(:list_refs)
        .with(gitaly_request_with_params(patterns: ['refs/heads/']), kind_of(Hash))
        .and_call_original

      client.list_refs
    end

    it 'accepts a patterns argument' do
      expect_any_instance_of(Gitaly::RefService::Stub)
        .to receive(:list_refs)
        .with(gitaly_request_with_params(patterns: ['refs/tags/']), kind_of(Hash))
        .and_call_original

      client.list_refs([Gitlab::Git::TAG_REF_PREFIX])
    end
  end

  describe '#pack_refs' do
    it 'sends a pack_refs message' do
      expect_any_instance_of(Gitaly::RefService::Stub)
        .to receive(:pack_refs)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return(double(:pack_refs_response))

      client.pack_refs
    end
  end

  describe '#find_refs_by_oid' do
    let(:oid) { project.repository.commit.id }

    it 'sends a find_refs_by_oid message' do
      expect_any_instance_of(Gitaly::RefService::Stub)
        .to receive(:find_refs_by_oid)
        .with(gitaly_request_with_params(sort_field: 'refname', oid: oid, limit: 1), kind_of(Hash))
        .and_call_original

      refs = client.find_refs_by_oid(oid: oid, limit: 1)

      expect(refs.to_a).to eq([Gitlab::Git::BRANCH_REF_PREFIX + project.repository.root_ref])
    end
  end
end
