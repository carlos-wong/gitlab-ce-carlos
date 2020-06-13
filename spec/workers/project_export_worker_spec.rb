# frozen_string_literal: true

require 'spec_helper'

describe ProjectExportWorker do
  let!(:user) { create(:user) }
  let!(:project) { create(:project) }

  subject { described_class.new }

  describe '#perform' do
    before do
      allow_next_instance_of(described_class) do |job|
        allow(job).to receive(:jid).and_return(SecureRandom.hex(8))
      end
    end

    context 'when it succeeds' do
      it 'calls the ExportService' do
        expect_any_instance_of(::Projects::ImportExport::ExportService).to receive(:execute)

        subject.perform(user.id, project.id, { 'klass' => 'Gitlab::ImportExport::AfterExportStrategies::DownloadNotificationStrategy' })
      end

      context 'export job' do
        before do
          allow_any_instance_of(::Projects::ImportExport::ExportService).to receive(:execute)
        end

        it 'creates an export job record for the project' do
          expect { subject.perform(user.id, project.id, {}) }.to change { project.export_jobs.count }.from(0).to(1)
        end

        it 'sets the export job status to started' do
          expect_next_instance_of(ProjectExportJob) do |job|
            expect(job).to receive(:start)
          end

          subject.perform(user.id, project.id, {})
        end

        it 'sets the export job status to finished' do
          expect_next_instance_of(ProjectExportJob) do |job|
            expect(job).to receive(:finish)
          end

          subject.perform(user.id, project.id, {})
        end
      end
    end

    context 'when it fails' do
      it 'does not raise an exception when strategy is invalid' do
        expect_any_instance_of(::Projects::ImportExport::ExportService).not_to receive(:execute)

        expect { subject.perform(user.id, project.id, { 'klass' => 'Whatever' }) }.not_to raise_error
      end

      it 'does not raise error when project cannot be found' do
        expect { subject.perform(user.id, -234, {}) }.not_to raise_error
      end

      it 'does not raise error when user cannot be found' do
        expect { subject.perform(-863, project.id, {}) }.not_to raise_error
      end
    end
  end
end
