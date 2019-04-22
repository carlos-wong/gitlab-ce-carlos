# frozen_string_literal: true

require 'spec_helper'

describe HashedStorage::MigratorWorker do
  subject(:worker) { described_class.new }
  let(:projects) { create_list(:project, 2, :legacy_storage, :empty_repo) }
  let(:ids) { projects.map(&:id) }

  describe '#perform' do
    it 'delegates to MigratorService' do
      expect_any_instance_of(Gitlab::HashedStorage::Migrator).to receive(:bulk_migrate).with(start: 5, finish: 10)

      worker.perform(5, 10)
    end

    it 'migrates projects in the specified range' do
      perform_enqueued_jobs do
        worker.perform(ids.min, ids.max)
      end

      projects.each do |project|
        expect(project.reload.hashed_storage?(:attachments)).to be_truthy
      end
    end
  end
end
