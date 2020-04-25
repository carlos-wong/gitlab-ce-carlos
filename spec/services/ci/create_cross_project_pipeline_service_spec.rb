# frozen_string_literal: true

require 'spec_helper'

describe Ci::CreateCrossProjectPipelineService, '#execute' do
  let_it_be(:user) { create(:user) }
  let(:upstream_project) { create(:project, :repository) }
  let_it_be(:downstream_project) { create(:project, :repository) }

  let!(:upstream_pipeline) do
    create(:ci_pipeline, :running, project: upstream_project)
  end

  let(:trigger) do
    {
      trigger: {
        project: downstream_project.full_path,
        branch: 'feature'
      }
    }
  end

  let(:bridge) do
    create(:ci_bridge, status: :pending,
                       user: user,
                       options: trigger,
                       pipeline: upstream_pipeline)
  end

  let(:service) { described_class.new(upstream_project, user) }

  before do
    upstream_project.add_developer(user)
  end

  context 'when downstream project has not been found' do
    let(:trigger) do
      { trigger: { project: 'unknown/project' } }
    end

    it 'does not create a pipeline' do
      expect { service.execute(bridge) }
        .not_to change { Ci::Pipeline.count }
    end

    it 'changes pipeline bridge job status to failed' do
      service.execute(bridge)

      expect(bridge.reload).to be_failed
      expect(bridge.failure_reason)
        .to eq 'downstream_bridge_project_not_found'
    end
  end

  context 'when user can not access downstream project' do
    it 'does not create a new pipeline' do
      expect { service.execute(bridge) }
        .not_to change { Ci::Pipeline.count }
    end

    it 'changes status of the bridge build' do
      service.execute(bridge)

      expect(bridge.reload).to be_failed
      expect(bridge.failure_reason)
        .to eq 'downstream_bridge_project_not_found'
    end
  end

  context 'when user does not have access to create pipeline' do
    before do
      downstream_project.add_guest(user)
    end

    it 'does not create a new pipeline' do
      expect { service.execute(bridge) }
        .not_to change { Ci::Pipeline.count }
    end

    it 'changes status of the bridge build' do
      service.execute(bridge)

      expect(bridge.reload).to be_failed
      expect(bridge.failure_reason).to eq 'insufficient_bridge_permissions'
    end
  end

  context 'when user can create pipeline in a downstream project' do
    let(:stub_config) { true }

    before do
      downstream_project.add_developer(user)
      stub_ci_pipeline_yaml_file(YAML.dump(rspec: { script: 'rspec' })) if stub_config
    end

    it 'creates only one new pipeline' do
      expect { service.execute(bridge) }
        .to change { Ci::Pipeline.count }.by(1)
    end

    it 'creates a new pipeline in a downstream project' do
      pipeline = service.execute(bridge)

      expect(pipeline.user).to eq bridge.user
      expect(pipeline.project).to eq downstream_project
      expect(bridge.sourced_pipelines.first.pipeline).to eq pipeline
      expect(pipeline.triggered_by_pipeline).to eq upstream_pipeline
      expect(pipeline.source_bridge).to eq bridge
      expect(pipeline.source_bridge).to be_a ::Ci::Bridge
    end

    it 'updates bridge status when downstream pipeline gets proceesed' do
      pipeline = service.execute(bridge)

      expect(pipeline.reload).to be_pending
      expect(bridge.reload).to be_success
    end

    context 'when target ref is not specified' do
      let(:trigger) do
        { trigger: { project: downstream_project.full_path } }
      end

      it 'is using default branch name' do
        pipeline = service.execute(bridge)

        expect(pipeline.ref).to eq 'master'
      end
    end

    context 'when downstream project is the same as the job project' do
      let(:trigger) do
        { trigger: { project: upstream_project.full_path } }
      end

      context 'detects a circular dependency' do
        it 'does not create a new pipeline' do
          expect { service.execute(bridge) }
            .not_to change { Ci::Pipeline.count }
        end

        it 'changes status of the bridge build' do
          service.execute(bridge)

          expect(bridge.reload).to be_failed
          expect(bridge.failure_reason).to eq 'invalid_bridge_trigger'
        end
      end

      context 'when "include" is provided' do
        let(:file_content) do
          YAML.dump(
            rspec: { script: 'rspec' },
            echo: { script: 'echo' })
        end

        shared_examples 'creates a child pipeline' do
          it 'creates only one new pipeline' do
            expect { service.execute(bridge) }
              .to change { Ci::Pipeline.count }.by(1)
          end

          it 'creates a child pipeline in the same project' do
            pipeline = service.execute(bridge)
            pipeline.reload

            expect(pipeline.builds.map(&:name)).to eq %w[rspec echo]
            expect(pipeline.user).to eq bridge.user
            expect(pipeline.project).to eq bridge.project
            expect(bridge.sourced_pipelines.first.pipeline).to eq pipeline
            expect(pipeline.triggered_by_pipeline).to eq upstream_pipeline
            expect(pipeline.source_bridge).to eq bridge
            expect(pipeline.source_bridge).to be_a ::Ci::Bridge
          end

          it 'updates bridge status when downstream pipeline gets proceesed' do
            pipeline = service.execute(bridge)

            expect(pipeline.reload).to be_pending
            expect(bridge.reload).to be_success
          end

          it 'propagates parent pipeline settings to the child pipeline' do
            pipeline = service.execute(bridge)
            pipeline.reload

            expect(pipeline.ref).to eq(upstream_pipeline.ref)
            expect(pipeline.sha).to eq(upstream_pipeline.sha)
            expect(pipeline.source_sha).to eq(upstream_pipeline.source_sha)
            expect(pipeline.target_sha).to eq(upstream_pipeline.target_sha)
            expect(pipeline.target_sha).to eq(upstream_pipeline.target_sha)

            expect(pipeline.trigger_requests.last).to eq(bridge.trigger_request)
          end
        end

        before do
          upstream_project.repository.create_file(
            user, 'child-pipeline.yml', file_content, message: 'message', branch_name: 'master')

          upstream_pipeline.update!(sha: upstream_project.commit.id)
        end

        let(:stub_config) { false }

        let(:trigger) do
          {
            trigger: { include: 'child-pipeline.yml' }
          }
        end

        it_behaves_like 'creates a child pipeline'

        context 'when latest sha for the ref changed in the meantime' do
          before do
            upstream_project.repository.create_file(
              user, 'another-change', 'test', message: 'message', branch_name: 'master')
          end

          # it does not auto-cancel pipelines from the same family
          it_behaves_like 'creates a child pipeline'
        end

        context 'when the parent is a merge request pipeline' do
          let(:merge_request) { create(:merge_request, source_project: bridge.project, target_project: bridge.project) }
          let(:file_content) do
            YAML.dump(
              workflow: { rules: [{ if: '$CI_MERGE_REQUEST_ID' }] },
              rspec: { script: 'rspec' },
              echo: { script: 'echo' })
          end

          before do
            bridge.pipeline.update!(source: :merge_request_event, merge_request: merge_request)
          end

          it_behaves_like 'creates a child pipeline'

          it 'propagates the merge request to the child pipeline' do
            pipeline = service.execute(bridge)

            expect(pipeline.merge_request).to eq(merge_request)
            expect(pipeline).to be_merge_request
          end
        end

        context 'when upstream pipeline is a child pipeline' do
          let!(:pipeline_source) do
            create(:ci_sources_pipeline,
              source_pipeline: create(:ci_pipeline, project: upstream_pipeline.project),
              pipeline: upstream_pipeline
            )
          end

          before do
            upstream_pipeline.update!(source: :parent_pipeline)
          end

          it 'does not create a further child pipeline' do
            expect { service.execute(bridge) }
              .not_to change { Ci::Pipeline.count }

            expect(bridge.reload).to be_failed
            expect(bridge.failure_reason).to eq 'bridge_pipeline_is_child_pipeline'
          end
        end
      end
    end

    context 'when bridge job has YAML variables defined' do
      before do
        bridge.yaml_variables = [{ key: 'BRIDGE', value: 'var', public: true }]
      end

      it 'passes bridge variables to downstream pipeline' do
        pipeline = service.execute(bridge)

        expect(pipeline.variables.first)
          .to have_attributes(key: 'BRIDGE', value: 'var')
      end
    end

    context 'when pipeline variables are defined' do
      before do
        upstream_pipeline.variables.create(key: 'PIPELINE_VARIABLE', value: 'my-value')
      end

      it 'does not pass pipeline variables directly downstream' do
        pipeline = service.execute(bridge)

        pipeline.variables.map(&:key).tap do |variables|
          expect(variables).not_to include 'PIPELINE_VARIABLE'
        end
      end

      context 'when using YAML variables interpolation' do
        before do
          bridge.yaml_variables = [{ key: 'BRIDGE', value: '$PIPELINE_VARIABLE-var', public: true }]
        end

        it 'makes it possible to pass pipeline variable downstream' do
          pipeline = service.execute(bridge)

          pipeline.variables.find_by(key: 'BRIDGE').tap do |variable|
            expect(variable.value).to eq 'my-value-var'
          end
        end
      end
    end

    # TODO: Move this context into a feature spec that uses
    # multiple pipeline processing services. Location TBD in:
    # https://gitlab.com/gitlab-org/gitlab/issues/36216
    context 'when configured with bridge job rules' do
      before do
        stub_ci_pipeline_yaml_file(config)
        downstream_project.add_maintainer(upstream_project.owner)
      end

      let(:config) do
        <<-EOY
          hello:
            script: echo world

          bridge-job:
            rules:
              - if: $CI_COMMIT_REF_NAME == "master"
            trigger:
              project: #{downstream_project.full_path}
              branch: master
        EOY
      end

      let(:primary_pipeline) do
        Ci::CreatePipelineService.new(upstream_project, upstream_project.owner, { ref: 'master' })
          .execute(:push, save_on_errors: false)
      end

      let(:bridge)  { primary_pipeline.processables.find_by(name: 'bridge-job') }
      let(:service) { described_class.new(upstream_project, upstream_project.owner) }

      context 'that include the bridge job' do
        it 'creates the downstream pipeline' do
          expect { service.execute(bridge) }
            .to change(downstream_project.ci_pipelines, :count).by(1)
        end
      end
    end

    context 'when user does not have access to push protected branch of downstream project' do
      before do
        create(:protected_branch, :maintainers_can_push,
               project: downstream_project, name: 'feature')
      end

      it 'changes status of the bridge build' do
        service.execute(bridge)

        expect(bridge.reload).to be_failed
        expect(bridge.failure_reason).to eq 'insufficient_bridge_permissions'
      end
    end
  end
end
