# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Packages::CleanupPackageRegistryWorker do
  describe '#perform' do
    let_it_be_with_reload(:package_files) { create_list(:package_file, 2, :pending_destruction) }
    let_it_be(:policy) { create(:packages_cleanup_policy, :runnable) }
    let_it_be(:package) { create(:package, project: policy.project) }

    let(:worker) { described_class.new }

    subject(:perform) { worker.perform }

    context 'with package files pending destruction' do
      it_behaves_like 'an idempotent worker'

      it 'queues the cleanup job' do
        expect(Packages::CleanupPackageFileWorker).to receive(:perform_with_capacity)

        perform
      end
    end

    context 'with no package files pending destruction' do
      before do
        ::Packages::PackageFile.update_all(status: :default)
      end

      it_behaves_like 'an idempotent worker'

      it 'does not queue the cleanup job' do
        expect(Packages::CleanupPackageFileWorker).not_to receive(:perform_with_capacity)

        perform
      end
    end

    context 'with runnable policies' do
      it_behaves_like 'an idempotent worker'

      it 'queues the cleanup job' do
        expect(Packages::Cleanup::ExecutePolicyWorker).to receive(:perform_with_capacity)

        perform
      end
    end

    context 'with no runnable policies' do
      before do
        policy.update_column(:next_run_at, 5.minutes.from_now)
      end

      it 'does not queue the cleanup job' do
        expect(Packages::Cleanup::ExecutePolicyWorker).not_to receive(:perform_with_capacity)

        perform
      end
    end

    describe 'counts logging' do
      let_it_be(:processing_package_file) { create(:package_file, status: :processing) }

      it 'logs all the counts', :aggregate_failures do
        expect(worker).to receive(:log_extra_metadata_on_done).with(:pending_destruction_package_files_count, 2)
        expect(worker).to receive(:log_extra_metadata_on_done).with(:processing_package_files_count, 1)
        expect(worker).to receive(:log_extra_metadata_on_done).with(:error_package_files_count, 0)
        expect(worker).to receive(:log_extra_metadata_on_done).with(:pending_cleanup_policies_count, 1)

        perform
      end

      context 'with load balancing enabled', :db_load_balancing do
        it 'reads the count from the replica' do
          expect(Gitlab::Database::LoadBalancing::Session.current).to receive(:use_replicas_for_read_queries).and_call_original

          perform
        end
      end
    end
  end
end
