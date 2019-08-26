# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Ci::Pipeline::Chain::Populate do
  set(:project) { create(:project, :repository) }
  set(:user) { create(:user) }

  let(:pipeline) do
    build(:ci_pipeline_with_one_job, project: project,
                                     ref: 'master',
                                     user: user)
  end

  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      project: project,
      current_user: user,
      origin_ref: 'master',
      seeds_block: nil)
  end

  let(:step) { described_class.new(pipeline, command) }

  context 'when pipeline doesn not have seeds block' do
    before do
      step.perform!
    end

    it 'does not persist the pipeline' do
      expect(pipeline).not_to be_persisted
    end

    it 'does not break the chain' do
      expect(step.break?).to be false
    end

    it 'populates pipeline with stages' do
      expect(pipeline.stages).to be_one
      expect(pipeline.stages.first).not_to be_persisted
      expect(pipeline.stages.first.statuses).to be_one
      expect(pipeline.stages.first.statuses.first).not_to be_persisted
    end

    it 'correctly assigns user' do
      expect(pipeline.builds).to all(have_attributes(user: user))
    end

    it 'has pipeline iid' do
      expect(pipeline.iid).to be > 0
    end
  end

  context 'when pipeline is empty' do
    let(:config) do
      { rspec: {
          script: 'ls',
          only: ['something']
      } }
    end

    let(:pipeline) do
      build(:ci_pipeline, project: project, config: config)
    end

    before do
      step.perform!
    end

    it 'breaks the chain' do
      expect(step.break?).to be true
    end

    it 'appends an error about missing stages' do
      expect(pipeline.errors.to_a)
        .to include 'No stages / jobs for this pipeline.'
    end

    it 'wastes pipeline iid' do
      expect(InternalId.ci_pipelines.where(project_id: project.id).last.last_value).to be > 0
    end
  end

  describe 'pipeline protect' do
    subject { step.perform! }

    context 'when ref is protected' do
      before do
        allow(project).to receive(:protected_for?).with('master').and_return(true)
        allow(project).to receive(:protected_for?).with('refs/heads/master').and_return(true)
      end

      it 'does not protect the pipeline' do
        subject

        expect(pipeline.protected).to eq(true)
      end
    end

    context 'when ref is not protected' do
      it 'does not protect the pipeline' do
        subject

        expect(pipeline.protected).to eq(false)
      end
    end
  end

  context 'when pipeline has validation errors' do
    let(:pipeline) do
      build(:ci_pipeline, project: project, ref: nil)
    end

    before do
      step.perform!
    end

    it 'breaks the chain' do
      expect(step.break?).to be true
    end

    it 'appends validation error' do
      expect(pipeline.errors.to_a)
        .to include 'Failed to build the pipeline!'
    end

    it 'wastes pipeline iid' do
      expect(InternalId.ci_pipelines.where(project_id: project.id).last.last_value).to be > 0
    end
  end

  context 'when there is a seed blocks present' do
    let(:command) do
      Gitlab::Ci::Pipeline::Chain::Command.new(
        project: project,
        current_user: user,
        origin_ref: 'master',
        seeds_block: seeds_block)
    end

    context 'when seeds block builds some resources' do
      let(:seeds_block) do
        ->(pipeline) { pipeline.variables.build(key: 'VAR', value: '123') }
      end

      it 'populates pipeline with resources described in the seeds block' do
        step.perform!

        expect(pipeline).not_to be_persisted
        expect(pipeline.variables).not_to be_empty
        expect(pipeline.variables.first).not_to be_persisted
        expect(pipeline.variables.first.key).to eq 'VAR'
        expect(pipeline.variables.first.value).to eq '123'
      end

      it 'has pipeline iid' do
        step.perform!

        expect(pipeline.iid).to be > 0
      end
    end

    context 'when seeds block tries to persist some resources' do
      let(:seeds_block) do
        ->(pipeline) { pipeline.variables.create!(key: 'VAR', value: '123') }
      end

      it 'wastes pipeline iid' do
        expect { step.perform! }.to raise_error(ActiveRecord::RecordNotSaved)

        last_iid = InternalId.ci_pipelines
          .where(project_id: project.id)
          .last.last_value

        expect(last_iid).to be > 0
      end
    end
  end

  context 'when pipeline gets persisted during the process' do
    let(:pipeline) { create(:ci_pipeline, project: project) }

    it 'raises error' do
      expect { step.perform! }.to raise_error(described_class::PopulateError)
    end
  end

  context 'when variables policy is specified' do
    shared_examples_for 'a correct pipeline' do
      it 'populates pipeline according to used policies' do
        step.perform!

        expect(pipeline.stages.size).to eq 1
        expect(pipeline.stages.first.statuses.size).to eq 1
        expect(pipeline.stages.first.statuses.first.name).to eq 'rspec'
      end
    end

    context 'when using only/except build policies' do
      let(:config) do
        { rspec: { script: 'rspec', stage: 'test', only: ['master'] },
          prod: { script: 'cap prod', stage: 'deploy', only: ['tags'] } }
      end

      let(:pipeline) do
        build(:ci_pipeline, ref: 'master', project: project, config: config)
      end

      it_behaves_like 'a correct pipeline'

      context 'when variables expression is specified' do
        context 'when pipeline iid is the subject' do
          let(:config) do
            { rspec: { script: 'rspec', only: { variables: ["$CI_PIPELINE_IID == '1'"] } },
              prod: { script: 'cap prod', only: { variables: ["$CI_PIPELINE_IID == '1000'"] } } }
          end

          it_behaves_like 'a correct pipeline'
        end
      end
    end
  end
end
