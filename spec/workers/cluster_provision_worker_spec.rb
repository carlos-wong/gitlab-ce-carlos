require 'spec_helper'

describe ClusterProvisionWorker do
  describe '#perform' do
    context 'when provider type is gcp' do
      let(:cluster) { create(:cluster, provider_type: :gcp, provider_gcp: provider) }
      let(:provider) { create(:cluster_provider_gcp, :scheduled) }

      it 'provision a cluster' do
        expect_any_instance_of(Clusters::Gcp::ProvisionService).to receive(:execute)

        described_class.new.perform(cluster.id)
      end
    end

    context 'when provider type is user' do
      let(:cluster) { create(:cluster, :provided_by_user) }

      it 'does not provision a cluster' do
        expect_any_instance_of(Clusters::Gcp::ProvisionService).not_to receive(:execute)

        described_class.new.perform(cluster.id)
      end

      it 'configures kubernetes platform' do
        expect(ClusterConfigureWorker).to receive(:perform_async).with(cluster.id)

        described_class.new.perform(cluster.id)
      end
    end

    context 'when cluster does not exist' do
      it 'does not provision a cluster' do
        expect_any_instance_of(Clusters::Gcp::ProvisionService).not_to receive(:execute)
        expect(ClusterConfigureWorker).not_to receive(:perform_async)

        described_class.new.perform(123)
      end
    end
  end
end
