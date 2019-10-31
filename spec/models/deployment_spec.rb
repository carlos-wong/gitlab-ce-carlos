# frozen_string_literal: true

require 'spec_helper'

describe Deployment do
  subject { build(:deployment) }

  it { is_expected.to belong_to(:project).required }
  it { is_expected.to belong_to(:environment).required }
  it { is_expected.to belong_to(:cluster).class_name('Clusters::Cluster') }
  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:deployable) }

  it { is_expected.to delegate_method(:name).to(:environment).with_prefix }
  it { is_expected.to delegate_method(:commit).to(:project) }
  it { is_expected.to delegate_method(:commit_title).to(:commit).as(:try) }
  it { is_expected.to delegate_method(:manual_actions).to(:deployable).as(:try) }

  it { is_expected.to validate_presence_of(:ref) }
  it { is_expected.to validate_presence_of(:sha) }

  it_behaves_like 'having unique enum values'

  describe '#scheduled_actions' do
    subject { deployment.scheduled_actions }

    let(:project) { create(:project, :repository) }
    let(:pipeline) { create(:ci_pipeline, project: project) }
    let(:build) { create(:ci_build, :success, pipeline: pipeline) }
    let(:deployment) { create(:deployment, deployable: build) }

    it 'delegates to other_scheduled_actions' do
      expect_any_instance_of(Ci::Build)
        .to receive(:other_scheduled_actions)

      subject
    end
  end

  describe 'modules' do
    it_behaves_like 'AtomicInternalId' do
      let(:internal_id_attribute) { :iid }
      let(:instance) { build(:deployment) }
      let(:scope) { :project }
      let(:scope_attrs) { { project: instance.project } }
      let(:usage) { :deployments }
    end
  end

  describe '.success' do
    subject { described_class.success }

    context 'when deployment status is success' do
      let(:deployment) { create(:deployment, :success) }

      it { is_expected.to eq([deployment]) }
    end

    context 'when deployment status is created' do
      let(:deployment) { create(:deployment, :created) }

      it { is_expected.to be_empty }
    end

    context 'when deployment status is running' do
      let(:deployment) { create(:deployment, :running) }

      it { is_expected.to be_empty }
    end
  end

  describe 'state machine' do
    context 'when deployment runs' do
      let(:deployment) { create(:deployment) }

      before do
        deployment.run!
      end

      it 'starts running' do
        Timecop.freeze do
          expect(deployment).to be_running
          expect(deployment.finished_at).to be_nil
        end
      end
    end

    context 'when deployment succeeded' do
      let(:deployment) { create(:deployment, :running) }

      it 'has correct status' do
        Timecop.freeze do
          deployment.succeed!

          expect(deployment).to be_success
          expect(deployment.finished_at).to be_like_time(Time.now)
        end
      end

      it 'executes Deployments::SuccessWorker asynchronously' do
        expect(Deployments::SuccessWorker)
          .to receive(:perform_async).with(deployment.id)

        deployment.succeed!
      end

      it 'executes Deployments::FinishedWorker asynchronously' do
        expect(Deployments::FinishedWorker)
          .to receive(:perform_async).with(deployment.id)

        deployment.succeed!
      end
    end

    context 'when deployment failed' do
      let(:deployment) { create(:deployment, :running) }

      it 'has correct status' do
        Timecop.freeze do
          deployment.drop!

          expect(deployment).to be_failed
          expect(deployment.finished_at).to be_like_time(Time.now)
        end
      end

      it 'executes Deployments::FinishedWorker asynchronously' do
        expect(Deployments::FinishedWorker)
          .to receive(:perform_async).with(deployment.id)

        deployment.drop!
      end
    end

    context 'when deployment was canceled' do
      let(:deployment) { create(:deployment, :running) }

      it 'has correct status' do
        Timecop.freeze do
          deployment.cancel!

          expect(deployment).to be_canceled
          expect(deployment.finished_at).to be_like_time(Time.now)
        end
      end

      it 'executes Deployments::FinishedWorker asynchronously' do
        expect(Deployments::FinishedWorker)
          .to receive(:perform_async).with(deployment.id)

        deployment.cancel!
      end
    end
  end

  describe '#success?' do
    subject { deployment.success? }

    context 'when deployment status is success' do
      let(:deployment) { create(:deployment, :success) }

      it { is_expected.to be_truthy }
    end

    context 'when deployment status is failed' do
      let(:deployment) { create(:deployment, :failed) }

      it { is_expected.to be_falsy }
    end
  end

  describe '#status_name' do
    subject { deployment.status_name }

    context 'when deployment status is success' do
      let(:deployment) { create(:deployment, :success) }

      it { is_expected.to eq(:success) }
    end

    context 'when deployment status is failed' do
      let(:deployment) { create(:deployment, :failed) }

      it { is_expected.to eq(:failed) }
    end
  end

  describe '#finished_at' do
    subject { deployment.finished_at }

    context 'when deployment status is created' do
      let(:deployment) { create(:deployment) }

      it { is_expected.to be_nil }
    end

    context 'when deployment status is success' do
      let(:deployment) { create(:deployment, :success) }

      it { is_expected.to eq(deployment.read_attribute(:finished_at)) }
    end

    context 'when deployment status is success' do
      let(:deployment) { create(:deployment, :success, finished_at: nil) }

      before do
        deployment.update_column(:finished_at, nil)
      end

      it { is_expected.to eq(deployment.read_attribute(:created_at)) }
    end

    context 'when deployment status is running' do
      let(:deployment) { create(:deployment, :running) }

      it { is_expected.to be_nil }
    end
  end

  describe '#deployed_at' do
    subject { deployment.deployed_at }

    context 'when deployment status is created' do
      let(:deployment) { create(:deployment) }

      it { is_expected.to be_nil }
    end

    context 'when deployment status is success' do
      let(:deployment) { create(:deployment, :success) }

      it { is_expected.to eq(deployment.read_attribute(:finished_at)) }
    end

    context 'when deployment status is running' do
      let(:deployment) { create(:deployment, :running) }

      it { is_expected.to be_nil }
    end
  end

  describe 'scopes' do
    describe 'last_for_environment' do
      let(:production) { create(:environment) }
      let(:staging) { create(:environment) }
      let(:testing) { create(:environment) }

      let!(:deployments) do
        [
          create(:deployment, environment: production),
          create(:deployment, environment: staging),
          create(:deployment, environment: production)
        ]
      end

      it 'retrieves last deployments for environments' do
        last_deployments = described_class.last_for_environment([staging, production, testing])

        expect(last_deployments.size).to eq(2)
        expect(last_deployments).to match_array(deployments.last(2))
      end
    end
  end

  describe '#includes_commit?' do
    let(:project) { create(:project, :repository) }
    let(:environment) { create(:environment, project: project) }
    let(:deployment) do
      create(:deployment, environment: environment, sha: project.commit.id)
    end

    context 'when there is no project commit' do
      it 'returns false' do
        commit = project.commit('feature')

        expect(deployment.includes_commit?(commit)).to be false
      end
    end

    context 'when they share the same tree branch' do
      it 'returns true' do
        commit = project.commit

        expect(deployment.includes_commit?(commit)).to be true
      end
    end

    context 'when the SHA for the deployment does not exist in the repo' do
      it 'returns false' do
        deployment.update(sha: Gitlab::Git::BLANK_SHA)
        commit = project.commit

        expect(deployment.includes_commit?(commit)).to be false
      end
    end
  end

  describe '#stop_action' do
    let(:build) { create(:ci_build) }

    subject { deployment.stop_action }

    context 'when no other actions' do
      let(:deployment) { FactoryBot.build(:deployment, deployable: build) }

      it { is_expected.to be_nil }
    end

    context 'with other actions' do
      let!(:close_action) { create(:ci_build, :manual, pipeline: build.pipeline, name: 'close_app') }

      context 'when matching action is defined' do
        let(:deployment) { FactoryBot.build(:deployment, deployable: build, on_stop: 'close_other_app') }

        it { is_expected.to be_nil }
      end

      context 'when no matching action is defined' do
        let(:deployment) { FactoryBot.build(:deployment, deployable: build, on_stop: 'close_app') }

        it { is_expected.to eq(close_action) }
      end
    end
  end

  describe '#deployed_by' do
    it 'returns the deployment user if there is no deployable' do
      deployment_user = create(:user)
      deployment = create(:deployment, deployable: nil, user: deployment_user)

      expect(deployment.deployed_by).to eq(deployment_user)
    end

    it 'returns the deployment user if the deployable have no user' do
      deployment_user = create(:user)
      build = create(:ci_build, user: nil)
      deployment = create(:deployment, deployable: build, user: deployment_user)

      expect(deployment.deployed_by).to eq(deployment_user)
    end

    it 'returns the deployable user if there is one' do
      build_user = create(:user)
      deployment_user = create(:user)
      build = create(:ci_build, user: build_user)
      deployment = create(:deployment, deployable: build, user: deployment_user)

      expect(deployment.deployed_by).to eq(build_user)
    end
  end

  describe '.find_successful_deployment!' do
    it 'returns a successful deployment' do
      deploy = create(:deployment, :success)

      expect(described_class.find_successful_deployment!(deploy.iid)).to eq(deploy)
    end

    it 'raises when no deployment is found' do
      expect { described_class.find_successful_deployment!(-1) }
        .to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
