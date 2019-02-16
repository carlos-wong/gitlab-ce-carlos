require 'rails_helper'

describe Clusters::Applications::Knative do
  include KubernetesHelpers
  include ReactiveCachingHelpers

  let(:knative) { create(:clusters_applications_knative) }

  include_examples 'cluster application core specs', :clusters_applications_knative
  include_examples 'cluster application status specs', :clusters_applications_knative
  include_examples 'cluster application helm specs', :clusters_applications_knative
  include_examples 'cluster application version specs', :clusters_applications_knative
  include_examples 'cluster application initial status specs'

  before do
    allow(ClusterWaitForIngressIpAddressWorker).to receive(:perform_in)
    allow(ClusterWaitForIngressIpAddressWorker).to receive(:perform_async)
  end

  describe 'when rbac is not enabled' do
    let(:cluster) { create(:cluster, :provided_by_gcp, :rbac_disabled) }
    let(:knative_no_rbac) { create(:clusters_applications_knative, cluster: cluster) }

    it { expect(knative_no_rbac).to be_not_installable }
  end

  describe '.installed' do
    subject { described_class.installed }

    let!(:cluster) { create(:clusters_applications_knative, :installed) }

    before do
      create(:clusters_applications_knative, :errored)
    end

    it { is_expected.to contain_exactly(cluster) }
  end

  describe '#make_installed' do
    subject { described_class.installed }

    let!(:cluster) { create(:clusters_applications_knative, :installed) }

    before do
      create(:clusters_applications_knative, :errored)
    end

    it { is_expected.to contain_exactly(cluster) }
  end

  describe 'make_installed with external_ip' do
    before do
      application.make_installed!
    end

    let(:application) { create(:clusters_applications_knative, :installing) }

    it 'schedules a ClusterWaitForIngressIpAddressWorker' do
      expect(ClusterWaitForIngressIpAddressWorker).to have_received(:perform_in)
        .with(Clusters::Applications::Knative::FETCH_IP_ADDRESS_DELAY, 'knative', application.id)
    end
  end

  describe '#schedule_status_update with external_ip' do
    let(:application) { create(:clusters_applications_knative, :installed) }

    before do
      application.schedule_status_update
    end

    it 'schedules a ClusterWaitForIngressIpAddressWorker' do
      expect(ClusterWaitForIngressIpAddressWorker).to have_received(:perform_async)
        .with('knative', application.id)
    end

    context 'when the application is not installed' do
      let(:application) { create(:clusters_applications_knative, :installing) }

      it 'does not schedule a ClusterWaitForIngressIpAddressWorker' do
        expect(ClusterWaitForIngressIpAddressWorker).not_to have_received(:perform_async)
      end
    end

    context 'when there is already an external_ip' do
      let(:application) { create(:clusters_applications_knative, :installed, external_ip: '111.222.222.111') }

      it 'does not schedule a ClusterWaitForIngressIpAddressWorker' do
        expect(ClusterWaitForIngressIpAddressWorker).not_to have_received(:perform_in)
      end
    end
  end

  describe '#install_command' do
    subject { knative.install_command }

    it 'should be an instance of Helm::InstallCommand' do
      expect(subject).to be_an_instance_of(Gitlab::Kubernetes::Helm::InstallCommand)
    end

    it 'should be initialized with knative arguments' do
      expect(subject.name).to eq('knative')
      expect(subject.chart).to eq('knative/knative')
      expect(subject.version).to eq('0.2.2')
      expect(subject.files).to eq(knative.files)
    end

    it 'should not install metrics for prometheus' do
      expect(subject.postinstall).to be_nil
    end

    context 'with prometheus installed' do
      let(:prometheus) { create(:clusters_applications_prometheus, :installed) }
      let(:knative) { create(:clusters_applications_knative, cluster: prometheus.cluster) }

      subject { knative.install_command }

      it 'should install metrics' do
        expect(subject.postinstall).not_to be_nil
        expect(subject.postinstall.length).to be(1)
        expect(subject.postinstall[0]).to eql("kubectl apply -f #{Clusters::Applications::Knative::METRICS_CONFIG}")
      end
    end
  end

  describe '#files' do
    let(:application) { knative }
    let(:values) { subject[:'values.yaml'] }

    subject { application.files }

    it 'should include knative specific keys in the values.yaml file' do
      expect(values).to include('domain')
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:hostname) }
  end

  describe '#service_pod_details' do
    let(:cluster) { create(:cluster, :project, :provided_by_gcp) }
    let(:service) { cluster.platform_kubernetes }
    let(:knative) { create(:clusters_applications_knative, cluster: cluster) }

    let(:namespace) do
      create(:cluster_kubernetes_namespace,
        cluster: cluster,
        cluster_project: cluster.cluster_project,
        project: cluster.cluster_project.project)
    end

    before do
      stub_kubeclient_discover(service.api_url)
      stub_kubeclient_knative_services
      stub_kubeclient_service_pods
      stub_reactive_cache(knative,
        {
          services: kube_response(kube_knative_services_body),
          pods: kube_response(kube_knative_pods_body(cluster.cluster_project.project.name, namespace.namespace))
        })
      synchronous_reactive_cache(knative)
    end

    it 'should be able k8s core for pod details' do
      expect(knative.service_pod_details(namespace.namespace, cluster.cluster_project.project.name)).not_to be_nil
    end
  end

  describe '#services' do
    let(:cluster) { create(:cluster, :project, :provided_by_gcp) }
    let(:service) { cluster.platform_kubernetes }
    let(:knative) { create(:clusters_applications_knative, cluster: cluster) }

    let(:namespace) do
      create(:cluster_kubernetes_namespace,
        cluster: cluster,
        cluster_project: cluster.cluster_project,
        project: cluster.cluster_project.project)
    end

    subject { knative.services }

    before do
      stub_kubeclient_discover(service.api_url)
      stub_kubeclient_knative_services
      stub_kubeclient_service_pods
    end

    it 'should have an unintialized cache' do
      is_expected.to be_nil
    end

    context 'when using synchronous reactive cache' do
      before do
        stub_reactive_cache(knative,
          {
            services: kube_response(kube_knative_services_body),
            pods: kube_response(kube_knative_pods_body(cluster.cluster_project.project.name, namespace.namespace))
          })
        synchronous_reactive_cache(knative)
      end

      it 'should have cached services' do
        is_expected.not_to be_nil
      end

      it 'should match our namespace' do
        expect(knative.services_for(ns: namespace)).not_to be_nil
      end
    end
  end
end
