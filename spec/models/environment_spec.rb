# frozen_string_literal: true

require 'spec_helper'

describe Environment do
  let(:project) { create(:project, :stubbed_repository) }
  subject(:environment) { create(:environment, project: project) }

  it { is_expected.to belong_to(:project) }
  it { is_expected.to have_many(:deployments) }

  it { is_expected.to delegate_method(:stop_action).to(:last_deployment) }
  it { is_expected.to delegate_method(:manual_actions).to(:last_deployment) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_uniqueness_of(:name).scoped_to(:project_id) }
  it { is_expected.to validate_length_of(:name).is_at_most(255) }

  it { is_expected.to validate_uniqueness_of(:slug).scoped_to(:project_id) }
  it { is_expected.to validate_length_of(:slug).is_at_most(24) }

  it { is_expected.to validate_length_of(:external_url).is_at_most(255) }

  describe '.order_by_last_deployed_at' do
    let(:project) { create(:project, :repository) }
    let!(:environment1) { create(:environment, project: project) }
    let!(:environment2) { create(:environment, project: project) }
    let!(:environment3) { create(:environment, project: project) }
    let!(:deployment1) { create(:deployment, environment: environment1) }
    let!(:deployment2) { create(:deployment, environment: environment2) }
    let!(:deployment3) { create(:deployment, environment: environment1) }

    it 'returns the environments in order of having been last deployed' do
      expect(project.environments.order_by_last_deployed_at.to_a).to eq([environment3, environment2, environment1])
    end
  end

  describe 'state machine' do
    it 'invalidates the cache after a change' do
      expect(environment).to receive(:expire_etag_cache)

      environment.stop
    end
  end

  describe '.for_name_like' do
    subject { project.environments.for_name_like(query, limit: limit) }

    let!(:environment) { create(:environment, name: 'production', project: project) }
    let(:query) { 'pro' }
    let(:limit) { 5 }

    it 'returns a found name' do
      is_expected.to include(environment)
    end

    context 'when query is production' do
      let(:query) { 'production' }

      it 'returns a found name' do
        is_expected.to include(environment)
      end
    end

    context 'when query is productionA' do
      let(:query) { 'productionA' }

      it 'returns empty array' do
        is_expected.to be_empty
      end
    end

    context 'when query is empty' do
      let(:query) { '' }

      it 'returns a found name' do
        is_expected.to include(environment)
      end
    end

    context 'when query is nil' do
      let(:query) { }

      it 'raises an error' do
        expect { subject }.to raise_error(NoMethodError)
      end
    end

    context 'when query is partially matched in the middle of environment name' do
      let(:query) { 'duction' }

      it 'returns empty array' do
        is_expected.to be_empty
      end
    end

    context 'when query contains a wildcard character' do
      let(:query) { 'produc%' }

      it 'prevents wildcard injection' do
        is_expected.to be_empty
      end
    end
  end

  describe '.pluck_names' do
    subject { described_class.pluck_names }

    let!(:environment) { create(:environment, name: 'production', project: project) }

    it 'plucks names' do
      is_expected.to eq(%w[production])
    end
  end

  describe '#expire_etag_cache' do
    let(:store) { Gitlab::EtagCaching::Store.new }

    it 'changes the cached value' do
      old_value = store.get(environment.etag_cache_key)

      environment.stop

      expect(store.get(environment.etag_cache_key)).not_to eq(old_value)
    end
  end

  describe '.with_deployment' do
    subject { described_class.with_deployment(sha) }

    let(:environment) { create(:environment) }
    let(:sha) { RepoHelpers.sample_commit.id }

    context 'when deployment has the specified sha' do
      let!(:deployment) { create(:deployment, environment: environment, sha: sha) }

      it { is_expected.to eq([environment]) }
    end

    context 'when deployment does not have the specified sha' do
      let!(:deployment) { create(:deployment, environment: environment, sha: 'abc') }

      it { is_expected.to be_empty }
    end
  end

  describe '#folder_name' do
    context 'when it is inside a folder' do
      subject(:environment) do
        create(:environment, name: 'staging/review-1')
      end

      it 'returns a top-level folder name' do
        expect(environment.folder_name).to eq 'staging'
      end
    end

    context 'when the environment if a top-level item itself' do
      subject(:environment) do
        create(:environment, name: 'production')
      end

      it 'returns an environment name' do
        expect(environment.folder_name).to eq 'production'
      end
    end
  end

  describe '#name_without_type' do
    context 'when it is inside a folder' do
      subject(:environment) do
        create(:environment, name: 'staging/review-1')
      end

      it 'returns name without folder' do
        expect(environment.name_without_type).to eq 'review-1'
      end
    end

    context 'when the environment if a top-level item itself' do
      subject(:environment) do
        create(:environment, name: 'production')
      end

      it 'returns full name' do
        expect(environment.name_without_type).to eq 'production'
      end
    end
  end

  describe '#nullify_external_url' do
    it 'replaces a blank url with nil' do
      env = build(:environment, external_url: "")

      expect(env.save).to be true
      expect(env.external_url).to be_nil
    end
  end

  describe '#includes_commit?' do
    let(:project) { create(:project, :repository) }

    context 'without a last deployment' do
      it "returns false" do
        expect(environment.includes_commit?('HEAD')).to be false
      end
    end

    context 'with a last deployment' do
      let!(:deployment) do
        create(:deployment, :success, environment: environment, sha: project.commit('master').id)
      end

      context 'in the same branch' do
        it 'returns true' do
          expect(environment.includes_commit?(RepoHelpers.sample_commit)).to be true
        end
      end

      context 'not in the same branch' do
        before do
          deployment.update(sha: project.commit('feature').id)
        end

        it 'returns false' do
          expect(environment.includes_commit?(RepoHelpers.sample_commit)).to be false
        end
      end
    end
  end

  describe '#update_merge_request_metrics?' do
    {
      'production' => true,
      'production/eu' => true,
      'production/www.gitlab.com' => true,
      'productioneu' => false,
      'Production' => false,
      'Production/eu' => false,
      'test-production' => false
    }.each do |name, expected_value|
      it "returns #{expected_value} for #{name}" do
        env = create(:environment, name: name)

        expect(env.update_merge_request_metrics?).to eq(expected_value)
      end
    end
  end

  describe '#first_deployment_for' do
    let(:project)       { create(:project, :repository) }
    let!(:deployment)   { create(:deployment, :succeed, environment: environment, ref: commit.parent.id) }
    let!(:deployment1)  { create(:deployment, :succeed, environment: environment, ref: commit.id) }
    let(:head_commit)   { project.commit }
    let(:commit)        { project.commit.parent }

    it 'returns deployment id for the environment' do
      expect(environment.first_deployment_for(commit.id)).to eq deployment1
    end

    it 'return nil when no deployment is found' do
      expect(environment.first_deployment_for(head_commit.id)).to eq nil
    end

    it 'returns a UTF-8 ref' do
      expect(environment.first_deployment_for(commit.id).ref).to be_utf8
    end
  end

  describe '#environment_type' do
    subject { environment.environment_type }

    it 'sets a environment type if name has multiple segments' do
      environment.update!(name: 'production/worker.gitlab.com')

      is_expected.to eq('production')
    end

    it 'nullifies a type if it\'s a simple name' do
      environment.update!(name: 'production')

      is_expected.to be_nil
    end
  end

  describe '#stop_action_available?' do
    subject { environment.stop_action_available? }

    context 'when no other actions' do
      it { is_expected.to be_falsey }
    end

    context 'when matching action is defined' do
      let(:build) { create(:ci_build) }

      let!(:deployment) do
        create(:deployment, :success,
                            environment: environment,
                            deployable: build,
                            on_stop: 'close_app')
      end

      let!(:close_action) do
        create(:ci_build, :manual, pipeline: build.pipeline,
                                   name: 'close_app')
      end

      context 'when environment is available' do
        before do
          environment.start
        end

        it { is_expected.to be_truthy }
      end

      context 'when environment is stopped' do
        before do
          environment.stop
        end

        it { is_expected.to be_falsey }
      end
    end
  end

  describe '#stop_with_action!' do
    let(:user) { create(:user) }

    subject { environment.stop_with_action!(user) }

    before do
      expect(environment).to receive(:available?).and_call_original
    end

    context 'when no other actions' do
      context 'environment is available' do
        before do
          environment.update(state: :available)
        end

        it do
          subject

          expect(environment).to be_stopped
        end
      end

      context 'environment is already stopped' do
        before do
          environment.update(state: :stopped)
        end

        it do
          subject

          expect(environment).to be_stopped
        end
      end
    end

    context 'when matching action is defined' do
      let(:pipeline) { create(:ci_pipeline, project: project) }
      let(:build) { create(:ci_build, pipeline: pipeline) }

      let!(:deployment) do
        create(:deployment, :success,
                            environment: environment,
                            deployable: build,
                            on_stop: 'close_app')
      end

      context 'when user is not allowed to stop environment' do
        let!(:close_action) do
          create(:ci_build, :manual, pipeline: pipeline, name: 'close_app')
        end

        it 'raises an exception' do
          expect { subject }.to raise_error(Gitlab::Access::AccessDeniedError)
        end
      end

      context 'when user is allowed to stop environment' do
        before do
          project.add_developer(user)

          create(:protected_branch, :developers_can_merge,
                 name: 'master', project: project)
        end

        context 'when action did not yet finish' do
          let!(:close_action) do
            create(:ci_build, :manual, pipeline: pipeline, name: 'close_app')
          end

          it 'returns the same action' do
            expect(subject).to eq(close_action)
            expect(subject.user).to eq(user)
          end
        end

        context 'if action did finish' do
          let!(:close_action) do
            create(:ci_build, :manual, :success,
                   pipeline: pipeline, name: 'close_app')
          end

          it 'returns a new action of the same type' do
            expect(subject).to be_persisted
            expect(subject.name).to eq(close_action.name)
            expect(subject.user).to eq(user)
          end
        end
      end
    end
  end

  describe 'recently_updated_on_branch?' do
    subject { environment.recently_updated_on_branch?('feature') }

    context 'when last deployment to environment is the most recent one' do
      before do
        create(:deployment, :success, environment: environment, ref: 'feature')
      end

      it { is_expected.to be true }
    end

    context 'when last deployment to environment is not the most recent' do
      before do
        create(:deployment, :success, environment: environment, ref: 'feature')
        create(:deployment, :success, environment: environment, ref: 'master')
      end

      it { is_expected.to be false }
    end
  end

  describe '#actions_for' do
    let(:deployment) { create(:deployment, :success, environment: environment) }
    let(:pipeline) { deployment.deployable.pipeline }
    let!(:review_action) { create(:ci_build, :manual, name: 'review-apps', pipeline: pipeline, environment: 'review/$CI_COMMIT_REF_NAME' )}
    let!(:production_action) { create(:ci_build, :manual, name: 'production', pipeline: pipeline, environment: 'production' )}

    it 'returns a list of actions with matching environment' do
      expect(environment.actions_for('review/master')).to contain_exactly(review_action)
    end
  end

  describe '.deployments' do
    subject { environment.deployments }

    context 'when there is a deployment record with created status' do
      let(:deployment) { create(:deployment, :created, environment: environment) }

      it 'does not return the record' do
        is_expected.to be_empty
      end
    end

    context 'when there is a deployment record with running status' do
      let(:deployment) { create(:deployment, :running, environment: environment) }

      it 'does not return the record' do
        is_expected.to be_empty
      end
    end

    context 'when there is a deployment record with success status' do
      let(:deployment) { create(:deployment, :success, environment: environment) }

      it 'returns the record' do
        is_expected.to eq([deployment])
      end
    end
  end

  describe '.last_deployment' do
    subject { environment.last_deployment }

    before do
      allow_any_instance_of(Deployment).to receive(:create_ref)
    end

    context 'when there is an old deployment record' do
      let!(:previous_deployment) { create(:deployment, :success, environment: environment) }

      context 'when there is a deployment record with created status' do
        let!(:deployment) { create(:deployment, environment: environment) }

        it 'returns the previous deployment' do
          is_expected.to eq(previous_deployment)
        end
      end

      context 'when there is a deployment record with running status' do
        let!(:deployment) { create(:deployment, :running, environment: environment) }

        it 'returns the previous deployment' do
          is_expected.to eq(previous_deployment)
        end
      end

      context 'when there is a deployment record with success status' do
        let!(:deployment) { create(:deployment, :success, environment: environment) }

        it 'returns the latest successful deployment' do
          is_expected.to eq(deployment)
        end
      end
    end
  end

  describe '#has_terminals?' do
    subject { environment.has_terminals? }

    context 'when the environment is available' do
      context 'with a deployment service' do
        shared_examples 'same behavior between KubernetesService and Platform::Kubernetes' do
          context 'and a deployment' do
            let!(:deployment) { create(:deployment, :success, environment: environment) }
            it { is_expected.to be_truthy }
          end

          context 'but no deployments' do
            it { is_expected.to be_falsy }
          end
        end

        context 'when user configured kubernetes from Integration > Kubernetes' do
          let(:project) { create(:kubernetes_project) }

          it_behaves_like 'same behavior between KubernetesService and Platform::Kubernetes'
        end

        context 'when user configured kubernetes from CI/CD > Clusters' do
          let!(:cluster) { create(:cluster, :project, :provided_by_gcp) }
          let(:project) { cluster.project }

          it_behaves_like 'same behavior between KubernetesService and Platform::Kubernetes'
        end
      end

      context 'without a deployment service' do
        it { is_expected.to be_falsy }
      end
    end

    context 'when the environment is unavailable' do
      let(:project) { create(:kubernetes_project) }

      before do
        environment.stop
      end

      it { is_expected.to be_falsy }
    end
  end

  describe '#deployment_platform' do
    context 'when there is a deployment platform for environment' do
      let!(:cluster) do
        create(:cluster, :provided_by_gcp,
               environment_scope: '*', projects: [project])
      end

      it 'finds a deployment platform' do
        expect(environment.deployment_platform).to eq cluster.platform
      end
    end

    context 'when there is no deployment platform for environment' do
      it 'returns nil' do
        expect(environment.deployment_platform).to be_nil
      end
    end

    it 'checks deployment platforms associated with a project' do
      expect(project).to receive(:deployment_platform)
        .with(environment: environment.name)

      environment.deployment_platform
    end
  end

  describe '#terminals' do
    subject { environment.terminals }

    context 'when the environment has terminals' do
      before do
        allow(environment).to receive(:has_terminals?).and_return(true)
      end

      shared_examples 'same behavior between KubernetesService and Platform::Kubernetes' do
        it 'returns the terminals from the deployment service' do
          deployment_platform_target = Gitlab.ee? ? environment : project

          expect(deployment_platform_target.deployment_platform)
            .to receive(:terminals).with(environment)
            .and_return(:fake_terminals)

          is_expected.to eq(:fake_terminals)
        end
      end

      context 'when user configured kubernetes from Integration > Kubernetes' do
        let(:project) { create(:kubernetes_project) }

        it_behaves_like 'same behavior between KubernetesService and Platform::Kubernetes'
      end

      context 'when user configured kubernetes from CI/CD > Clusters' do
        let!(:cluster) { create(:cluster, :project, :provided_by_gcp) }
        let(:project) { cluster.project }

        it_behaves_like 'same behavior between KubernetesService and Platform::Kubernetes'
      end
    end

    context 'when the environment does not have terminals' do
      before do
        allow(environment).to receive(:has_terminals?).and_return(false)
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#has_metrics?' do
    subject { environment.has_metrics? }

    context 'when the environment is available' do
      context 'with a deployment service' do
        let(:project) { create(:prometheus_project) }

        context 'and a deployment' do
          let!(:deployment) { create(:deployment, environment: environment) }
          it { is_expected.to be_truthy }
        end

        context 'and no deployments' do
          it { is_expected.to be_truthy }
        end
      end

      context 'without a monitoring service' do
        it { is_expected.to be_falsy }
      end
    end

    context 'when the environment is unavailable' do
      let(:project) { create(:prometheus_project) }

      before do
        environment.stop
      end

      it { is_expected.to be_falsy }
    end
  end

  describe '#metrics' do
    let(:project) { create(:prometheus_project) }
    subject { environment.metrics }

    context 'when the environment has metrics' do
      before do
        allow(environment).to receive(:has_metrics?).and_return(true)
      end

      it 'returns the metrics from the deployment service' do
        expect(environment.prometheus_adapter)
          .to receive(:query).with(:environment, environment)
          .and_return(:fake_metrics)

        is_expected.to eq(:fake_metrics)
      end
    end

    context 'when the environment does not have metrics' do
      before do
        allow(environment).to receive(:has_metrics?).and_return(false)
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#additional_metrics' do
    let(:project) { create(:prometheus_project) }
    let(:metric_params) { [] }
    subject { environment.additional_metrics(*metric_params) }

    context 'when the environment has additional metrics' do
      before do
        allow(environment).to receive(:has_metrics?).and_return(true)
      end

      it 'returns the additional metrics from the deployment service' do
        expect(environment.prometheus_adapter)
          .to receive(:query)
          .with(:additional_metrics_environment, environment)
          .and_return(:fake_metrics)

        is_expected.to eq(:fake_metrics)
      end

      context 'when time window arguments are provided' do
        let(:metric_params) { [1552642245.067, Time.now] }

        it 'queries with the expected parameters' do
          expect(environment.prometheus_adapter)
            .to receive(:query)
            .with(:additional_metrics_environment, environment, *metric_params.map(&:to_f))
            .and_return(:fake_metrics)

          is_expected.to eq(:fake_metrics)
        end
      end
    end

    context 'when the environment does not have metrics' do
      before do
        allow(environment).to receive(:has_metrics?).and_return(false)
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#slug' do
    it "is automatically generated" do
      expect(environment.slug).not_to be_nil
    end

    it "is not regenerated if name changes" do
      original_slug = environment.slug
      environment.update!(name: environment.name.reverse)

      expect(environment.slug).to eq(original_slug)
    end

    it "regenerates the slug if nil" do
      environment = build(:environment, slug: nil)

      new_slug = environment.slug

      expect(new_slug).not_to be_nil
      expect(environment.slug).to eq(new_slug)
    end
  end

  describe '#generate_slug' do
    SUFFIX = "-[a-z0-9]{6}".freeze
    {
      "staging-12345678901234567" => "staging-123456789" + SUFFIX,
      "9-staging-123456789012345" => "env-9-staging-123" + SUFFIX,
      "staging-1234567890123456"  => "staging-1234567890123456",
      "production"                => "production",
      "PRODUCTION"                => "production" + SUFFIX,
      "review/1-foo"              => "review-1-foo" + SUFFIX,
      "1-foo"                     => "env-1-foo" + SUFFIX,
      "1/foo"                     => "env-1-foo" + SUFFIX,
      "foo-"                      => "foo" + SUFFIX,
      "foo--bar"                  => "foo-bar" + SUFFIX,
      "foo**bar"                  => "foo-bar" + SUFFIX,
      "*-foo"                     => "env-foo" + SUFFIX,
      "staging-12345678-"         => "staging-12345678" + SUFFIX,
      "staging-12345678-01234567" => "staging-12345678" + SUFFIX
    }.each do |name, matcher|
      it "returns a slug matching #{matcher}, given #{name}" do
        slug = described_class.new(name: name).generate_slug

        expect(slug).to match(/\A#{matcher}\z/)
      end
    end
  end

  describe '#ref_path' do
    subject(:environment) do
      create(:environment, name: 'staging / review-1')
    end

    it 'returns a path that uses the slug and does not have spaces' do
      expect(environment.ref_path).to start_with('refs/environments/staging-review-1-')
    end

    it "doesn't change when the slug is nil initially" do
      environment.slug = nil

      expect(environment.ref_path).to eq(environment.ref_path)
    end
  end

  describe '#external_url_for' do
    let(:source_path) { 'source/file.html' }
    let(:sha) { RepoHelpers.sample_commit.id }

    before do
      environment.external_url = 'http://example.com'
    end

    context 'when the public path is not known' do
      before do
        allow(project).to receive(:public_path_for_source_path).with(source_path, sha).and_return(nil)
      end

      it 'returns nil' do
        expect(environment.external_url_for(source_path, sha)).to be_nil
      end
    end

    context 'when the public path is known' do
      before do
        allow(project).to receive(:public_path_for_source_path).with(source_path, sha).and_return('file.html')
      end

      it 'returns the full external URL' do
        expect(environment.external_url_for(source_path, sha)).to eq('http://example.com/file.html')
      end
    end
  end

  describe '#prometheus_adapter' do
    it 'calls prometheus adapter service' do
      expect_any_instance_of(Prometheus::AdapterService).to receive(:prometheus_adapter)

      subject.prometheus_adapter
    end
  end
end
