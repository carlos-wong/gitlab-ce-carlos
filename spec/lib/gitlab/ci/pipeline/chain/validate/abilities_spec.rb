# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Ci::Pipeline::Chain::Validate::Abilities do
  let_it_be(:project, reload: true) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }

  let(:pipeline) do
    build_stubbed(:ci_pipeline, project: project)
  end

  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      project: project,
      current_user: user,
      origin_ref: origin_ref,
      merge_request: merge_request,
      trigger_request: trigger_request)
  end

  let(:step) { described_class.new(pipeline, command) }

  let(:ref) { 'master' }
  let(:origin_ref) { ref }
  let(:merge_request) { nil }
  let(:trigger_request) { nil }

  shared_context 'detached merge request pipeline' do
    let(:merge_request) do
      create(:merge_request,
        source_project: project,
        source_branch: ref,
        target_project: project,
        target_branch: 'feature')
    end

    let(:pipeline) do
      build(:ci_pipeline,
        source: :merge_request_event,
        merge_request: merge_request,
        project: project)
    end

    let(:origin_ref) { merge_request.ref_path }
  end

  context 'when users has no ability to run a pipeline' do
    before do
      step.perform!
    end

    it 'adds an error about insufficient permissions' do
      expect(pipeline.errors.to_a)
        .to include /Insufficient permissions/
    end

    it 'breaks the pipeline builder chain' do
      expect(step.break?).to eq true
    end
  end

  context 'when user has ability to create a pipeline' do
    before do
      project.add_developer(user)

      step.perform!
    end

    it 'does not invalidate the pipeline' do
      expect(pipeline).to be_valid
    end

    it 'does not break the chain' do
      expect(step.break?).to eq false
    end
  end

  describe '#allowed_to_write_ref?' do
    subject { step.send(:allowed_to_write_ref?) }

    context 'when user is a developer' do
      before do
        project.add_developer(user)
      end

      it { is_expected.to be_truthy }

      context 'when pipeline is a detached merge request pipeline' do
        include_context 'detached merge request pipeline'

        it { is_expected.to be_truthy }
      end

      context 'when the branch is protected' do
        let!(:protected_branch) do
          create(:protected_branch, project: project, name: ref)
        end

        it { is_expected.to be_falsey }

        context 'when pipeline is a detached merge request pipeline' do
          include_context 'detached merge request pipeline'

          it { is_expected.to be_falsey }
        end

        context 'when developers are allowed to merge' do
          let!(:protected_branch) do
            create(:protected_branch,
                   :developers_can_merge,
                   project: project,
                   name: ref)
          end

          it { is_expected.to be_truthy }

          context 'when pipeline is a detached merge request pipeline' do
            include_context 'detached merge request pipeline'

            it { is_expected.to be_truthy }
          end
        end
      end

      context 'when the tag is protected' do
        let(:ref) { 'v1.0.0' }

        let!(:protected_tag) do
          create(:protected_tag, project: project, name: ref)
        end

        it { is_expected.to be_falsey }

        context 'when developers are allowed to create the tag' do
          let!(:protected_tag) do
            create(:protected_tag,
                   :developers_can_create,
                   project: project,
                   name: ref)
          end

          it { is_expected.to be_truthy }
        end
      end
    end

    context 'when user is a maintainer' do
      before do
        project.add_maintainer(user)
      end

      it { is_expected.to be_truthy }

      context 'when the branch is protected' do
        let!(:protected_branch) do
          create(:protected_branch, project: project, name: ref)
        end

        it { is_expected.to be_truthy }

        context 'when pipeline is a detached merge request pipeline' do
          include_context 'detached merge request pipeline'

          it { is_expected.to be_truthy }
        end
      end

      context 'when the tag is protected' do
        let(:ref) { 'v1.0.0' }

        let!(:protected_tag) do
          create(:protected_tag, project: project, name: ref)
        end

        it { is_expected.to be_truthy }

        context 'when no one can create the tag' do
          let!(:protected_tag) do
            create(:protected_tag,
                   :no_one_can_create,
                   project: project,
                   name: ref)
          end

          it { is_expected.to be_falsey }
        end
      end
    end

    context 'when owner cannot create pipeline' do
      it { is_expected.to be_falsey }
    end
  end
end
