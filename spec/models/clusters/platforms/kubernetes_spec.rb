require 'spec_helper'

describe Clusters::Platforms::Kubernetes, :use_clean_rails_memory_store_caching do
  include KubernetesHelpers
  include ReactiveCachingHelpers

  it { is_expected.to belong_to(:cluster) }
  it { is_expected.to be_kind_of(Gitlab::Kubernetes) }
  it { is_expected.to be_kind_of(ReactiveCaching) }
  it { is_expected.to respond_to :ca_pem }

  it { is_expected.to validate_exclusion_of(:namespace).in_array(%w(gitlab-managed-apps)) }
  it { is_expected.to validate_presence_of(:api_url) }
  it { is_expected.to validate_presence_of(:token) }

  it { is_expected.to delegate_method(:project).to(:cluster) }
  it { is_expected.to delegate_method(:enabled?).to(:cluster) }
  it { is_expected.to delegate_method(:managed?).to(:cluster) }
  it { is_expected.to delegate_method(:kubernetes_namespace).to(:cluster) }

  it_behaves_like 'having unique enum values'

  describe 'before_validation' do
    context 'when namespace includes upper case' do
      let(:kubernetes) { create(:cluster_platform_kubernetes, :configured, namespace: namespace) }
      let(:namespace) { 'ABC' }

      it 'converts to lower case' do
        expect(kubernetes.namespace).to eq('abc')
      end
    end
  end

  describe 'validation' do
    subject { kubernetes.valid? }

    context 'when validates namespace' do
      let(:kubernetes) { build(:cluster_platform_kubernetes, :configured, namespace: namespace) }

      context 'when namespace is blank' do
        let(:namespace) { '' }

        it { is_expected.to be_truthy }
      end

      context 'when namespace is longer than 63' do
        let(:namespace) { 'a' * 64 }

        it { is_expected.to be_falsey }
      end

      context 'when namespace includes invalid character' do
        let(:namespace) { '!!!!!!' }

        it { is_expected.to be_falsey }
      end

      context 'when namespace is vaild' do
        let(:namespace) { 'namespace-123' }

        it { is_expected.to be_truthy }
      end

      context 'for group cluster' do
        let(:namespace) { 'namespace-123' }
        let(:cluster) { build(:cluster, :group, :provided_by_user) }
        let(:kubernetes) { cluster.platform_kubernetes }

        before do
          kubernetes.namespace = namespace
        end

        it { is_expected.to be_falsey }
      end
    end

    context 'when validates api_url' do
      let(:kubernetes) { build(:cluster_platform_kubernetes, :configured) }

      before do
        kubernetes.api_url = api_url
      end

      context 'when api_url is invalid url' do
        let(:api_url) { '!!!!!!' }

        it { expect(kubernetes.save).to be_falsey }
      end

      context 'when api_url is nil' do
        let(:api_url) { nil }

        it { expect(kubernetes.save).to be_falsey }
      end

      context 'when api_url is valid url' do
        let(:api_url) { 'https://111.111.111.111' }

        it { expect(kubernetes.save).to be_truthy }
      end
    end

    context 'when validates token' do
      let(:kubernetes) { build(:cluster_platform_kubernetes, :configured) }

      before do
        kubernetes.token = token
      end

      context 'when token is nil' do
        let(:token) { nil }

        it { expect(kubernetes.save).to be_falsey }
      end
    end

    describe 'when using reserved namespaces' do
      subject { build(:cluster_platform_kubernetes, namespace: namespace) }

      context 'when no namespace is manually assigned' do
        let(:namespace) { nil }

        it { is_expected.to be_valid }
      end

      context 'when no reserved namespace is assigned' do
        let(:namespace) { 'my-namespace' }

        it { is_expected.to be_valid }
      end

      context 'when reserved namespace is assigned' do
        let(:namespace) { 'gitlab-managed-apps' }

        it { is_expected.not_to be_valid }
      end
    end
  end

  describe '#kubeclient' do
    let(:cluster) { create(:cluster, :project) }
    let(:kubernetes) { build(:cluster_platform_kubernetes, :configured, namespace: 'a-namespace', cluster: cluster) }

    subject { kubernetes.kubeclient }

    before do
      create(:cluster_kubernetes_namespace,
             cluster: kubernetes.cluster,
             cluster_project: kubernetes.cluster.cluster_project,
             project: kubernetes.cluster.cluster_project.project)
    end

    it { is_expected.to be_an_instance_of(Gitlab::Kubernetes::KubeClient) }
  end

  describe '#rbac?' do
    subject { kubernetes.rbac? }

    let(:kubernetes) { build(:cluster_platform_kubernetes, :configured) }

    context 'when authorization type is rbac' do
      let(:kubernetes) { build(:cluster_platform_kubernetes, :rbac_enabled, :configured) }

      it { is_expected.to be_truthy }
    end

    context 'when authorization type is nil' do
      it { is_expected.to be_falsey }
    end
  end

  describe '#actual_namespace' do
    let(:cluster) { create(:cluster, :project) }
    let(:project) { cluster.project }

    let(:platform) do
      create(:cluster_platform_kubernetes,
             cluster: cluster,
             namespace: namespace)
    end

    subject { platform.actual_namespace }

    context 'with a namespace assigned' do
      let(:namespace) { 'namespace-123' }

      it { is_expected.to eq(namespace) }
    end

    context 'with no namespace assigned' do
      let(:namespace) { nil }

      context 'when kubernetes namespace is present' do
        let(:kubernetes_namespace) { create(:cluster_kubernetes_namespace, cluster: cluster) }

        before do
          kubernetes_namespace
        end

        it { is_expected.to eq(kubernetes_namespace.namespace) }
      end

      context 'when kubernetes namespace is not present' do
        it { is_expected.to eq("#{project.path}-#{project.id}") }
      end
    end
  end

  describe '#predefined_variables' do
    let!(:cluster) { create(:cluster, :project, platform_kubernetes: kubernetes) }
    let(:kubernetes) { create(:cluster_platform_kubernetes, api_url: api_url, ca_cert: ca_pem) }
    let(:api_url) { 'https://kube.domain.com' }
    let(:ca_pem) { 'CA PEM DATA' }

    subject { kubernetes.predefined_variables(project: cluster.project) }

    shared_examples 'setting variables' do
      it 'sets the variables' do
        expect(subject).to include(
          { key: 'KUBE_URL', value: api_url, public: true },
          { key: 'KUBE_CA_PEM', value: ca_pem, public: true },
          { key: 'KUBE_CA_PEM_FILE', value: ca_pem, public: true, file: true }
        )
      end
    end

    context 'kubernetes namespace is created with no service account token' do
      let!(:kubernetes_namespace) { create(:cluster_kubernetes_namespace, cluster: cluster) }

      it_behaves_like 'setting variables'

      it 'sets KUBE_TOKEN' do
        expect(subject).to include(
          { key: 'KUBE_TOKEN', value: kubernetes.token, public: false }
        )
      end
    end

    context 'kubernetes namespace is created with no service account token' do
      let!(:kubernetes_namespace) { create(:cluster_kubernetes_namespace, :with_token, cluster: cluster) }

      it_behaves_like 'setting variables'

      it 'sets KUBE_TOKEN' do
        expect(subject).to include(
          { key: 'KUBE_TOKEN', value: kubernetes_namespace.service_account_token, public: false }
        )
      end
    end

    context 'namespace is provided' do
      let(:namespace) { 'my-project' }

      before do
        kubernetes.namespace = namespace
      end

      it_behaves_like 'setting variables'

      it 'sets KUBE_TOKEN' do
        expect(subject).to include(
          { key: 'KUBE_TOKEN', value: kubernetes.token, public: false }
        )
      end
    end

    context 'no namespace provided' do
      let(:namespace) { kubernetes.actual_namespace }

      it_behaves_like 'setting variables'

      it 'sets KUBE_TOKEN' do
        expect(subject).to include(
          { key: 'KUBE_TOKEN', value: kubernetes.token, public: false }
        )
      end
    end

    context 'group level cluster' do
      let!(:cluster) { create(:cluster, :group, platform_kubernetes: kubernetes) }

      let(:project) { create(:project, group: cluster.group) }

      subject { kubernetes.predefined_variables(project: project) }

      context 'no kubernetes namespace for the project' do
        it_behaves_like 'setting variables'

        it 'does not return KUBE_TOKEN' do
          expect(subject).not_to include(
            { key: 'KUBE_TOKEN', value: kubernetes.token, public: false }
          )
        end
      end

      context 'kubernetes namespace exists for the project' do
        let!(:kubernetes_namespace) { create(:cluster_kubernetes_namespace, :with_token, cluster: cluster, project: project) }

        it_behaves_like 'setting variables'

        it 'sets KUBE_TOKEN' do
          expect(subject).to include(
            { key: 'KUBE_TOKEN', value: kubernetes_namespace.service_account_token, public: false }
          )
        end
      end
    end
  end

  describe '#terminals' do
    subject { service.terminals(environment) }

    let!(:cluster) { create(:cluster, :project, platform_kubernetes: service) }
    let(:project) { cluster.project }
    let(:service) { create(:cluster_platform_kubernetes, :configured) }
    let(:environment) { build(:environment, project: project, name: "env", slug: "env-000000") }

    context 'with invalid pods' do
      it 'returns no terminals' do
        stub_reactive_cache(service, pods: [{ "bad" => "pod" }])

        is_expected.to be_empty
      end
    end

    context 'with valid pods' do
      let(:pod) { kube_pod(app: environment.slug) }
      let(:pod_with_no_terminal) { kube_pod(app: environment.slug, status: "Pending") }
      let(:terminals) { kube_terminals(service, pod) }

      before do
        stub_reactive_cache(
          service,
          pods: [pod, pod, pod_with_no_terminal, kube_pod(app: "should-be-filtered-out")]
        )
      end

      it 'returns terminals' do
        is_expected.to eq(terminals + terminals)
      end

      it 'uses max session time from settings' do
        stub_application_setting(terminal_max_session_time: 600)

        times = subject.map { |terminal| terminal[:max_session_time] }
        expect(times).to eq [600, 600, 600, 600]
      end
    end
  end

  describe '#calculate_reactive_cache' do
    subject { service.calculate_reactive_cache }

    let!(:cluster) { create(:cluster, :project, enabled: enabled, platform_kubernetes: service) }
    let(:service) { create(:cluster_platform_kubernetes, :configured) }
    let(:enabled) { true }

    context 'when cluster is disabled' do
      let(:enabled) { false }

      it { is_expected.to be_nil }
    end

    context 'when kubernetes responds with valid pods and deployments' do
      before do
        stub_kubeclient_pods
        stub_kubeclient_deployments
      end

      it { is_expected.to include(pods: [kube_pod]) }
    end

    context 'when kubernetes responds with 500s' do
      before do
        stub_kubeclient_pods(status: 500)
        stub_kubeclient_deployments(status: 500)
      end

      it { expect { subject }.to raise_error(Kubeclient::HttpError) }
    end

    context 'when kubernetes responds with 404s' do
      before do
        stub_kubeclient_pods(status: 404)
        stub_kubeclient_deployments(status: 404)
      end

      it { is_expected.to include(pods: []) }
    end
  end

  describe '#update_kubernetes_namespace' do
    let(:cluster) { create(:cluster, :provided_by_gcp) }
    let(:platform) { cluster.platform }

    context 'when namespace is updated' do
      it 'should call ConfigureWorker' do
        expect(ClusterConfigureWorker).to receive(:perform_async).with(cluster.id).once

        platform.namespace = 'new-namespace'
        platform.save
      end
    end

    context 'when namespace is not updated' do
      it 'should not call ConfigureWorker' do
        expect(ClusterConfigureWorker).not_to receive(:perform_async)

        platform.username = "new-username"
        platform.save
      end
    end
  end
end
