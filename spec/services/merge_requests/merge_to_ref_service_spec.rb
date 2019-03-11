# frozen_string_literal: true

require 'spec_helper'

describe MergeRequests::MergeToRefService do
  shared_examples_for 'MergeService for target ref' do
    it 'target_ref has the same state of target branch' do
      repo = merge_request.target_project.repository

      process_merge_to_ref
      merge_service.execute(merge_request)

      ref_commits = repo.commits(merge_request.merge_ref_path, limit: 3)
      target_branch_commits = repo.commits(merge_request.target_branch, limit: 3)

      ref_commits.zip(target_branch_commits).each do |ref_commit, target_branch_commit|
        expect(ref_commit.parents).to eq(target_branch_commit.parents)
      end
    end
  end

  shared_examples_for 'successfully merges to ref with merge method' do
    it 'writes commit to merge ref' do
      repository = project.repository
      target_ref = merge_request.merge_ref_path

      expect(repository.ref_exists?(target_ref)).to be(false)

      result = service.execute(merge_request)

      ref_head = repository.commit(target_ref)

      expect(result[:status]).to eq(:success)
      expect(result[:commit_id]).to be_present
      expect(result[:source_id]).to eq(merge_request.source_branch_sha)
      expect(result[:target_id]).to eq(merge_request.target_branch_sha)
      expect(repository.ref_exists?(target_ref)).to be(true)
      expect(ref_head.id).to eq(result[:commit_id])
    end
  end

  shared_examples_for 'successfully evaluates pre-condition checks' do
    it 'returns error when feature is disabled' do
      stub_feature_flags(merge_to_tmp_merge_ref_path: false)

      result = service.execute(merge_request)

      expect(result[:status]).to eq(:error)
      expect(result[:message]).to eq('Feature is not enabled')
    end

    it 'returns an error when the failing to process the merge' do
      allow(project.repository).to receive(:merge_to_ref).and_return(nil)

      result = service.execute(merge_request)

      expect(result[:status]).to eq(:error)
      expect(result[:message]).to eq('Conflicts detected during merge')
    end

    it 'does not send any mail' do
      expect { process_merge_to_ref }.not_to change { ActionMailer::Base.deliveries.count }
    end

    it 'does not change the MR state' do
      expect { process_merge_to_ref }.not_to change { merge_request.state }
    end

    it 'does not create notes' do
      expect { process_merge_to_ref }.not_to change { merge_request.notes.count }
    end

    it 'does not delete the source branch' do
      expect(DeleteBranchService).not_to receive(:new)

      process_merge_to_ref
    end
  end

  set(:user) { create(:user) }
  let(:merge_request) { create(:merge_request, :simple) }
  let(:project) { merge_request.project }

  before do
    project.add_maintainer(user)
  end

  describe '#execute' do
    let(:service) do
      described_class.new(project, user, commit_message: 'Awesome message',
                                         should_remove_source_branch: true)
    end

    def process_merge_to_ref
      perform_enqueued_jobs do
        service.execute(merge_request)
      end
    end

    it_behaves_like 'successfully merges to ref with merge method'
    it_behaves_like 'successfully evaluates pre-condition checks'

    context 'commit history comparison with regular MergeService' do
      let(:merge_ref_service) do
        described_class.new(project, user, {})
      end

      let(:merge_service) do
        MergeRequests::MergeService.new(project, user, {})
      end

      context 'when merge commit' do
        it_behaves_like 'MergeService for target ref'
      end

      context 'when merge commit with squash' do
        before do
          merge_request.update!(squash: true, source_branch: 'master', target_branch: 'feature')
        end

        it_behaves_like 'MergeService for target ref'
      end
    end

    context 'merge pre-condition checks' do
      before do
        merge_request.project.update!(merge_method: merge_method)
      end

      context 'when semi-linear merge method' do
        let(:merge_method) { :rebase_merge }

        it_behaves_like 'successfully merges to ref with merge method'
        it_behaves_like 'successfully evaluates pre-condition checks'
      end

      context 'when fast-forward merge method' do
        let(:merge_method) { :ff }

        it_behaves_like 'successfully merges to ref with merge method'
        it_behaves_like 'successfully evaluates pre-condition checks'
      end

      context 'when MR is not mergeable to ref' do
        let(:merge_method) { :merge }

        it 'returns error' do
          allow(merge_request).to receive(:mergeable_to_ref?) { false }

          error_message = "Merge request is not mergeable to #{merge_request.merge_ref_path}"

          result = service.execute(merge_request)

          expect(result[:status]).to eq(:error)
          expect(result[:message]).to eq(error_message)
        end
      end
    end

    context 'does not close related todos' do
      let(:merge_request) { create(:merge_request, assignee: user, author: user) }
      let(:project) { merge_request.project }
      let!(:todo) do
        create(:todo, :assigned,
               project: project,
               author: user,
               user: user,
               target: merge_request)
      end

      before do
        allow(service).to receive(:execute_hooks)

        perform_enqueued_jobs do
          service.execute(merge_request)
          todo.reload
        end
      end

      it { expect(todo).not_to be_done }
    end

    it 'returns error when user has no authorization to admin the merge request' do
      unauthorized_user = create(:user)
      project.add_reporter(unauthorized_user)

      service = described_class.new(project, unauthorized_user)

      result = service.execute(merge_request)

      expect(result[:status]).to eq(:error)
      expect(result[:message]).to eq('You are not allowed to merge to this ref')
    end
  end
end
