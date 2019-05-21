require 'spec_helper'

describe Ci::PipelinePolicy, :models do
  let(:user) { create(:user) }
  let(:pipeline) { create(:ci_empty_pipeline, project: project) }

  let(:policy) do
    described_class.new(user, pipeline)
  end

  describe 'rules' do
    describe 'rules for protected ref' do
      let(:project) { create(:project, :repository) }

      before do
        project.add_developer(user)
      end

      context 'when no one can push or merge to the branch' do
        before do
          create(:protected_branch, :no_one_can_push,
                 name: pipeline.ref, project: project)
        end

        it 'does not include ability to update pipeline' do
          expect(policy).to be_disallowed :update_pipeline
        end
      end

      context 'when developers can push to the branch' do
        before do
          create(:protected_branch, :developers_can_merge,
                 name: pipeline.ref, project: project)
        end

        it 'includes ability to update pipeline' do
          expect(policy).to be_allowed :update_pipeline
        end
      end

      context 'when no one can create the tag' do
        before do
          create(:protected_tag, :no_one_can_create,
                 name: pipeline.ref, project: project)

          pipeline.update(tag: true)
        end

        it 'does not include ability to update pipeline' do
          expect(policy).to be_disallowed :update_pipeline
        end
      end

      context 'when no one can create the tag but it is not a tag' do
        before do
          create(:protected_tag, :no_one_can_create,
                 name: pipeline.ref, project: project)
        end

        it 'includes ability to update pipeline' do
          expect(policy).to be_allowed :update_pipeline
        end
      end
    end

    context 'when maintainer is allowed to push to pipeline branch' do
      let(:project) { create(:project, :public) }
      let(:owner) { user }

      it 'enables update_pipeline if user is maintainer' do
        allow_any_instance_of(Project).to receive(:empty_repo?).and_return(false)
        allow_any_instance_of(Project).to receive(:branch_allows_collaboration?).and_return(true)

        expect(policy).to be_allowed :update_pipeline
      end
    end

    context 'when user does not have access to internal CI' do
      let(:project) { create(:project, :builds_disabled, :public) }

      it 'disallows the user from reading the pipeline' do
        expect(policy).to be_disallowed :read_pipeline
      end
    end

    describe 'destroy_pipeline' do
      let(:project) { create(:project, :public) }

      context 'when user has owner access' do
        let(:user) { project.owner }

        it 'is enabled' do
          expect(policy).to be_allowed :destroy_pipeline
        end
      end

      context 'when user is not owner' do
        it 'is disabled' do
          expect(policy).not_to be_allowed :destroy_pipeline
        end
      end
    end

    describe 'read_pipeline_variable' do
      let(:project) { create(:project, :public) }

      context 'when user has owner access' do
        let(:user) { project.owner }

        it 'is enabled' do
          expect(policy).to be_allowed :read_pipeline_variable
        end
      end

      context 'when user is developer and the creator of the pipeline' do
        let(:pipeline) { create(:ci_empty_pipeline, project: project, user: user) }

        before do
          project.add_developer(user)
          create(:protected_branch, :developers_can_merge,
                 name: pipeline.ref, project: project)
        end

        it 'is enabled' do
          expect(policy).to be_allowed :read_pipeline_variable
        end
      end

      context 'when user is developer and it is not the creator of the pipeline' do
        let(:pipeline) { create(:ci_empty_pipeline, project: project, user: project.owner) }

        before do
          project.add_developer(user)
          create(:protected_branch, :developers_can_merge,
                 name: pipeline.ref, project: project)
        end

        it 'is disabled' do
          expect(policy).to be_disallowed :read_pipeline_variable
        end
      end

      context 'when user is not owner nor developer' do
        it 'is disabled' do
          expect(policy).not_to be_allowed :read_pipeline_variable
        end
      end
    end
  end
end
