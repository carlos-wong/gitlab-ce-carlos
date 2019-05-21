require 'spec_helper'

describe Gitlab::GitalyClient::CleanupService do
  let(:project) { create(:project) }
  let(:storage_name) { project.repository_storage }
  let(:relative_path) { project.disk_path + '.git' }
  let(:client) { described_class.new(project.repository) }

  describe '#apply_bfg_object_map_stream' do
    it 'sends an apply_bfg_object_map_stream message' do
      expect_any_instance_of(Gitaly::CleanupService::Stub)
        .to receive(:apply_bfg_object_map_stream)
        .with(kind_of(Enumerator), kind_of(Hash))
        .and_return([])

      client.apply_bfg_object_map_stream(StringIO.new)
    end
  end
end
