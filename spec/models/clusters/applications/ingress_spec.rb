require 'rails_helper'

describe Clusters::Applications::Ingress do
  let(:ingress) { create(:clusters_applications_ingress) }

  it_behaves_like 'having unique enum values'

  include_examples 'cluster application core specs', :clusters_applications_ingress
  include_examples 'cluster application status specs', :clusters_applications_ingress
  include_examples 'cluster application version specs', :clusters_applications_ingress
  include_examples 'cluster application helm specs', :clusters_applications_ingress
  include_examples 'cluster application initial status specs'

  before do
    allow(ClusterWaitForIngressIpAddressWorker).to receive(:perform_in)
    allow(ClusterWaitForIngressIpAddressWorker).to receive(:perform_async)
  end

  describe '.installed' do
    subject { described_class.installed }

    let!(:cluster) { create(:clusters_applications_ingress, :installed) }

    before do
      create(:clusters_applications_ingress, :errored)
    end

    it { is_expected.to contain_exactly(cluster) }
  end

  describe '#make_installed!' do
    before do
      application.make_installed!
    end

    let(:application) { create(:clusters_applications_ingress, :installing) }

    it 'schedules a ClusterWaitForIngressIpAddressWorker' do
      expect(ClusterWaitForIngressIpAddressWorker).to have_received(:perform_in)
        .with(Clusters::Applications::Ingress::FETCH_IP_ADDRESS_DELAY, 'ingress', application.id)
    end
  end

  describe '#schedule_status_update' do
    let(:application) { create(:clusters_applications_ingress, :installed) }

    before do
      application.schedule_status_update
    end

    it 'schedules a ClusterWaitForIngressIpAddressWorker' do
      expect(ClusterWaitForIngressIpAddressWorker).to have_received(:perform_async)
        .with('ingress', application.id)
    end

    context 'when the application is not installed' do
      let(:application) { create(:clusters_applications_ingress, :installing) }

      it 'does not schedule a ClusterWaitForIngressIpAddressWorker' do
        expect(ClusterWaitForIngressIpAddressWorker).not_to have_received(:perform_async)
      end
    end

    context 'when there is already an external_ip' do
      let(:application) { create(:clusters_applications_ingress, :installed, external_ip: '111.222.222.111') }

      it 'does not schedule a ClusterWaitForIngressIpAddressWorker' do
        expect(ClusterWaitForIngressIpAddressWorker).not_to have_received(:perform_in)
      end
    end
  end

  describe '#install_command' do
    subject { ingress.install_command }

    it { is_expected.to be_an_instance_of(Gitlab::Kubernetes::Helm::InstallCommand) }

    it 'should be initialized with ingress arguments' do
      expect(subject.name).to eq('ingress')
      expect(subject.chart).to eq('stable/nginx-ingress')
      expect(subject.version).to eq('1.1.2')
      expect(subject).to be_rbac
      expect(subject.files).to eq(ingress.files)
    end

    context 'on a non rbac enabled cluster' do
      before do
        ingress.cluster.platform_kubernetes.abac!
      end

      it { is_expected.not_to be_rbac }
    end

    context 'application failed to install previously' do
      let(:ingress) { create(:clusters_applications_ingress, :errored, version: 'nginx') }

      it 'should be initialized with the locked version' do
        expect(subject.version).to eq('1.1.2')
      end
    end
  end

  describe '#files' do
    let(:application) { ingress }
    let(:values) { subject[:'values.yaml'] }

    subject { application.files }

    it 'should include ingress valid keys in values' do
      expect(values).to include('image')
      expect(values).to include('repository')
      expect(values).to include('stats')
      expect(values).to include('podAnnotations')
    end
  end
end
