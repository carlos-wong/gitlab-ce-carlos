require 'spec_helper'

describe Gitlab::Graphql::Loaders::BatchLfsOidLoader do
  include GraphqlHelpers

  set(:project) { create(:project, :repository) }
  let(:repository) { project.repository }
  let(:blob) { Gitlab::Graphql::Representation::TreeEntry.new(repository.blob_at('master', 'files/lfs/lfs_object.iso'), repository) }
  let(:otherblob) { Gitlab::Graphql::Representation::TreeEntry.new(repository.blob_at('master', 'README'), repository) }

  describe '#find' do
    it 'batch-resolves LFS blob IDs' do
      expect(Gitlab::Git::Blob).to receive(:batch_lfs_pointers).once.and_call_original

      result = batch do
        [blob, otherblob].map { |b| described_class.new(repository, b.id).find }
      end

      expect(result.first).to eq(blob.lfs_oid)
      expect(result.last).to eq(nil)
    end
  end
end
