# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Environments::StopService do
  include CreateEnvironmentsHelpers

  let(:project) { create(:project, :private, :repository) }
  let(:user) { create(:user) }

  let(:service) { described_class.new(project, user) }

  describe '#execute' do
    subject { service.execute(environment) }

    let_it_be(:project) { create(:project, :private, :repository) }
    let_it_be(:developer) { create(:user).tap { |u| project.add_developer(u) } }
    let_it_be(:reporter) { create(:user).tap { |u| project.add_reporter(u) } }

    let(:user) { developer }

    context 'with a deployment' do
      let!(:environment) { review_job.persisted_environment }
      let!(:pipeline) { create(:ci_pipeline, project: project) }
      let!(:review_job) { create(:ci_build, :with_deployment, :start_review_app, pipeline: pipeline, project: project) }
      let!(:stop_review_job) { create(:ci_build, :with_deployment, :stop_review_app, :manual, pipeline: pipeline, project: project) }

      before do
        review_job.success!
      end

      it 'stops the environment' do
        expect { subject }.to change { environment.reload.state }.from('available').to('stopped')
      end

      it 'plays the stop action' do
        expect { subject }.to change { stop_review_job.reload.status }.from('manual').to('pending')
      end

      context 'when an environment has already been stopped' do
        let!(:environment) { create(:environment, :stopped, project: project) }

        it 'does not play the stop action' do
          expect { subject }.not_to change { stop_review_job.reload.status }
        end
      end
    end

    context 'without a deployment' do
      let!(:environment) { create(:environment, project: project) }

      it 'stops the environment' do
        expect { subject }.to change { environment.reload.state }.from('available').to('stopped')
      end

      context 'when the actor is a reporter' do
        let(:user) { reporter }

        it 'does not stop the environment' do
          expect { subject }.not_to change { environment.reload.state }
        end
      end
    end
  end

  describe '#execute_for_branch' do
    context 'when environment with review app exists' do
      before do
        create(:environment, :with_review_app, project: project,
                                               ref: 'feature')
      end

      context 'when user has permission to stop environment' do
        before do
          project.add_developer(user)
        end

        context 'when environment is associated with removed branch' do
          it 'stops environment' do
            expect_environment_stopped_on('feature')
          end
        end

        context 'when environment is associated with different branch' do
          it 'does not stop environment' do
            expect_environment_not_stopped_on('master')
          end
        end

        context 'when specified branch does not exist' do
          it 'does not stop environment' do
            expect_environment_not_stopped_on('non/existent/branch')
          end
        end

        context 'when no branch not specified' do
          it 'does not stop environment' do
            expect_environment_not_stopped_on(nil)
          end
        end

        context 'when environment is not stopped' do
          before do
            allow_next_found_instance_of(Environment) do |environment|
              allow(environment).to receive(:state).and_return(:stopped)
            end
          end

          it 'does not stop environment' do
            expect_environment_not_stopped_on('feature')
          end
        end
      end

      context 'when user does not have permission to stop environment' do
        context 'when user has no access to manage deployments' do
          before do
            project.add_guest(user)
          end

          it 'does not stop environment' do
            expect_environment_not_stopped_on('master')
          end
        end
      end

      context 'when branch for stop action is protected' do
        before do
          project.add_developer(user)
          create(:protected_branch, :no_one_can_push,
                 name: 'master', project: project)
        end

        it 'does not stop environment' do
          expect_environment_not_stopped_on('master')
        end
      end
    end

    context 'when there is no environment associated with review app' do
      before do
        create(:environment, project: project)
      end

      context 'when user has permission to stop environments' do
        before do
          project.add_maintainer(user)
        end

        it 'does not stop environment' do
          expect_environment_not_stopped_on('master')
        end
      end
    end

    context 'when environment does not exist' do
      it 'does not raise error' do
        expect { service.execute_for_branch('master') }
          .not_to raise_error
      end
    end
  end

  describe '#execute_for_merge_request' do
    subject { service.execute_for_merge_request(merge_request) }

    let(:merge_request) { create(:merge_request, source_branch: 'feature', target_branch: 'master') }
    let(:project) { merge_request.project }
    let(:user) { create(:user) }

    let(:pipeline) do
      create(:ci_pipeline,
        source: :merge_request_event,
        merge_request: merge_request,
        project: project,
        sha: merge_request.diff_head_sha,
        merge_requests_as_head_pipeline: [merge_request])
    end

    let!(:review_job) { create(:ci_build, :with_deployment, :start_review_app, pipeline: pipeline, project: project) }
    let!(:stop_review_job) { create(:ci_build, :with_deployment, :stop_review_app, :manual, pipeline: pipeline, project: project) }

    before do
      review_job.deployment.success!
    end

    it 'has active environment at first' do
      expect(pipeline.environments_in_self_and_descendants.first).to be_available
    end

    context 'when user is a developer' do
      before do
        project.add_developer(user)
      end

      it 'stops the active environment' do
        subject

        expect(pipeline.environments_in_self_and_descendants.first).to be_stopped
      end

      context 'with environment related jobs ' do
        let!(:environment) { create(:environment, :available, name: 'staging', project: project) }
        let!(:prepare_staging_job) { create(:ci_build, :prepare_staging, pipeline: pipeline, project: project) }
        let!(:start_staging_job) { create(:ci_build, :start_staging, :with_deployment, :manual, pipeline: pipeline, project: project) }
        let!(:stop_staging_job) { create(:ci_build, :stop_staging, :manual, pipeline: pipeline, project: project) }

        it 'does not stop environments that was not started by the merge request' do
          subject

          expect(prepare_staging_job.persisted_environment.state).to eq('available')
        end

        context 'when fix_related_environments_for_merge_requests feature flag is disabled' do
          before do
            stub_feature_flags(fix_related_environments_for_merge_requests: false)
          end

          it 'stops unrelated environments too' do
            subject

            expect(prepare_staging_job.persisted_environment.state).to eq('stopped')
          end
        end
      end
    end

    context 'when user is a reporter' do
      before do
        project.add_reporter(user)
      end

      it 'does not stop the active environment' do
        subject

        expect(pipeline.environments_in_self_and_descendants.first).to be_available
      end
    end

    context 'when pipeline is not associated with environments' do
      let!(:job) { create(:ci_build, pipeline: pipeline, project: project) }

      it 'does not raise exception' do
        expect { subject }.not_to raise_exception
      end
    end

    context 'when pipeline is not a pipeline for merge request' do
      let(:pipeline) do
        create(:ci_pipeline,
          project: project,
          ref: 'feature',
          sha: merge_request.diff_head_sha,
          merge_requests_as_head_pipeline: [merge_request])
      end

      it 'does not stop the active environment' do
        subject

        expect(pipeline.environments_in_self_and_descendants.first).to be_available
      end
    end
  end

  def expect_environment_stopped_on(branch)
    expect { service.execute_for_branch(branch) }
      .to change { Environment.last.state }.from('available').to('stopped')
  end

  def expect_environment_not_stopped_on(branch)
    expect { service.execute_for_branch(branch) }
      .not_to change { Environment.last.state }
  end
end
