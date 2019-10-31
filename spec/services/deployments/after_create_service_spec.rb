# frozen_string_literal: true

require 'spec_helper'

describe Deployments::AfterCreateService do
  let(:user) { create(:user) }
  let(:project) { create(:project, :repository) }
  let(:options) { { name: 'production' } }

  let(:job) do
    create(:ci_build,
      :with_deployment,
      ref: 'master',
      tag: false,
      environment: 'production',
      options: { environment: options },
      project: project)
  end

  let(:deployment) { job.deployment }
  let(:environment) { deployment.environment }

  subject(:service) { described_class.new(deployment) }

  before do
    allow(Deployments::FinishedWorker).to receive(:perform_async)
    job.success! # Create/Succeed deployment
  end

  describe '#execute' do
    let(:store) { Gitlab::EtagCaching::Store.new }

    it 'invalidates the environment etag cache' do
      old_value = store.get(environment.etag_cache_key)

      service.execute

      expect(store.get(environment.etag_cache_key)).not_to eq(old_value)
    end

    it 'creates ref' do
      expect_any_instance_of(Repository)
        .to receive(:create_ref)
        .with(deployment.ref, deployment.send(:ref_path))

      service.execute
    end

    it 'updates merge request metrics' do
      expect_any_instance_of(Deployment)
        .to receive(:update_merge_request_metrics!)

      service.execute
    end

    it 'returns the deployment' do
      expect(subject.execute).to eq(deployment)
    end

    it 'returns the deployment when could not save the environment' do
      allow(environment).to receive(:save).and_return(false)

      expect(subject.execute).to eq(deployment)
    end

    it 'returns the deployment when environment is stopped' do
      allow(environment).to receive(:stopped?).and_return(true)

      expect(subject.execute).to eq(deployment)
    end

    context 'when start action is defined' do
      let(:options) { { name: 'production', action: 'start' } }

      context 'and environment is stopped' do
        before do
          environment.stop
        end

        it 'makes environment available' do
          service.execute

          expect(environment.reload).to be_available
        end
      end
    end

    context 'when variables are used' do
      let(:options) do
        { name: 'review-apps/$CI_COMMIT_REF_NAME',
          url: 'http://$CI_COMMIT_REF_NAME.review-apps.gitlab.com' }
      end

      before do
        environment.update(name: 'review-apps/master')
        job.update(environment: 'review-apps/$CI_COMMIT_REF_NAME')
      end

      it 'does not create a new environment' do
        expect { subject.execute }.not_to change { Environment.count }
      end

      it 'updates external url' do
        subject.execute

        expect(subject.environment.name).to eq('review-apps/master')
        expect(subject.environment.external_url).to eq('http://master.review-apps.gitlab.com')
      end
    end
  end

  describe '#expanded_environment_url' do
    subject { service.send(:expanded_environment_url) }

    context 'when yaml environment uses $CI_COMMIT_REF_NAME' do
      let(:job) do
        create(:ci_build,
               :with_deployment,
               ref: 'master',
               environment: 'production',
               project: project,
               options: { environment: { name: 'production', url: 'http://review/$CI_COMMIT_REF_NAME' } })
      end

      it { is_expected.to eq('http://review/master') }
    end

    context 'when yaml environment uses $CI_ENVIRONMENT_SLUG' do
      let(:job) do
        create(:ci_build,
               :with_deployment,
               ref: 'master',
               environment: 'prod-slug',
               project: project,
               options: { environment: { name: 'prod-slug', url: 'http://review/$CI_ENVIRONMENT_SLUG' } })
      end

      it { is_expected.to eq('http://review/prod-slug') }
    end

    context 'when yaml environment uses yaml_variables containing symbol keys' do
      let(:job) do
        create(:ci_build,
               :with_deployment,
               yaml_variables: [{ key: :APP_HOST, value: 'host' }],
               environment: 'production',
               project: project,
               options: { environment: { name: 'production', url: 'http://review/$APP_HOST' } })
      end

      it { is_expected.to eq('http://review/host') }
    end

    context 'when yaml environment does not have url' do
      let(:job) { create(:ci_build, :with_deployment, environment: 'staging', project: project) }

      it 'returns the external_url from persisted environment' do
        is_expected.to be_nil
      end
    end
  end

  describe "merge request metrics" do
    let(:merge_request) { create(:merge_request, target_branch: 'master', source_branch: 'feature', source_project: project) }

    context "while updating the 'first_deployed_to_production_at' time" do
      before do
        merge_request.metrics.update!(merged_at: 1.hour.ago)
      end

      context "for merge requests merged before the current deploy" do
        it "sets the time if the deploy's environment is 'production'" do
          service.execute

          expect(merge_request.reload.metrics.first_deployed_to_production_at).to be_like_time(deployment.finished_at)
        end

        context 'when job deploys to staging' do
          let(:job) do
            create(:ci_build,
              :with_deployment,
              ref: 'master',
              tag: false,
              environment: 'staging',
              options: { environment: { name: 'staging' } },
              project: project)
          end

          it "doesn't set the time if the deploy's environment is not 'production'" do
            service.execute

            expect(merge_request.reload.metrics.first_deployed_to_production_at).to be_nil
          end
        end

        it 'does not raise errors if the merge request does not have a metrics record' do
          merge_request.metrics.destroy

          expect(merge_request.reload.metrics).to be_nil
          expect { service.execute }.not_to raise_error
        end
      end

      context "for merge requests merged before the previous deploy" do
        context "if the 'first_deployed_to_production_at' time is already set" do
          it "does not overwrite the older 'first_deployed_to_production_at' time" do
            # Previous deploy
            service.execute

            expect(merge_request.reload.metrics.first_deployed_to_production_at).to be_like_time(deployment.finished_at)

            # Current deploy
            Timecop.travel(12.hours.from_now) do
              service.execute

              expect(merge_request.reload.metrics.first_deployed_to_production_at).to be_like_time(deployment.finished_at)
            end
          end
        end

        context "if the 'first_deployed_to_production_at' time is not already set" do
          it "does not overwrite the older 'first_deployed_to_production_at' time" do
            # Previous deploy
            time = 5.minutes.from_now
            Timecop.freeze(time) { service.execute }

            expect(merge_request.reload.metrics.merged_at).to be < merge_request.reload.metrics.first_deployed_to_production_at

            previous_time = merge_request.reload.metrics.first_deployed_to_production_at

            # Current deploy
            Timecop.freeze(time + 12.hours) { service.execute }

            expect(merge_request.reload.metrics.first_deployed_to_production_at).to eq(previous_time)
          end
        end
      end
    end
  end
end
