# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BulkImports::RelationExportService do
  let_it_be(:jid) { 'jid' }
  let_it_be(:relation) { 'labels' }
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project) }
  let_it_be(:label) { create(:group_label, group: group) }
  let_it_be(:export_path) { "#{Dir.tmpdir}/relation_export_service_spec/tree" }
  let_it_be_with_reload(:export) { create(:bulk_import_export, group: group, relation: relation) }

  before do
    group.add_owner(user)
    project.add_maintainer(user)

    allow(export).to receive(:export_path).and_return(export_path)
  end

  after :all do
    FileUtils.rm_rf(export_path)
  end

  subject { described_class.new(user, group, relation, jid) }

  describe '#execute' do
    it 'exports specified relation and marks export as finished' do
      expect_next_instance_of(BulkImports::TreeExportService) do |service|
        expect(service).to receive(:execute).and_call_original
      end

      subject.execute

      expect(export.reload.upload.export_file).to be_present
      expect(export.finished?).to eq(true)
    end

    it 'removes temp export files' do
      subject.execute

      expect(Dir.exist?(export_path)).to eq(false)
    end

    it 'exports specified relation and marks export as finished' do
      subject.execute

      expect(export.upload.export_file).to be_present
    end

    context 'when exporting a file relation' do
      it 'uses file export service' do
        service = described_class.new(user, project, 'uploads', jid)

        expect_next_instance_of(BulkImports::FileExportService) do |service|
          expect(service).to receive(:execute)
        end

        service.execute
      end
    end

    context 'when export record does not exist' do
      let(:another_group) { create(:group) }

      subject { described_class.new(user, another_group, relation, jid) }

      it 'creates export record' do
        another_group.add_owner(user)

        expect { subject.execute }
          .to change { another_group.bulk_import_exports.count }
          .from(0)
          .to(1)
      end
    end

    context 'when there is existing export present' do
      let(:upload) { create(:bulk_import_export_upload, export: export) }

      it 'removes existing export before exporting' do
        upload.update!(export_file: fixture_file_upload('spec/fixtures/bulk_imports/gz/labels.ndjson.gz'))

        expect_any_instance_of(BulkImports::ExportUpload) do |upload|
          expect(upload).to receive(:remove_export_file!)
        end

        subject.execute
      end

      context 'when export is recently finished' do
        it 'returns recently finished export instead of re-exporting' do
          updated_at = 5.seconds.ago
          export.update!(status: 1, updated_at: updated_at)

          expect { subject.execute }.not_to change { export.updated_at }

          expect(export.status).to eq(1)
          expect(export.updated_at).to eq(updated_at)
        end
      end
    end

    context 'when exception occurs during export' do
      shared_examples 'tracks exception' do |exception_class|
        it 'tracks exception' do
          expect(Gitlab::ErrorTracking)
            .to receive(:track_exception)
            .with(exception_class, portable_id: group.id, portable_type: group.class.name)
            .and_call_original

          subject.execute
        end
      end

      before do
        allow_next_instance_of(BulkImports::ExportUpload) do |upload|
          allow(upload).to receive(:save!).and_raise(StandardError)
        end
      end

      it 'marks export as failed' do
        subject.execute

        expect(export.reload.failed?).to eq(true)
      end

      include_examples 'tracks exception', StandardError

      context 'when passed relation is not supported' do
        let(:relation) { 'unsupported' }

        include_examples 'tracks exception', ActiveRecord::RecordInvalid
      end

      context 'when user is not allowed to perform export' do
        let(:another_user) { create(:user) }

        subject { described_class.new(another_user, group, relation, jid) }

        include_examples 'tracks exception', Gitlab::ImportExport::Error
      end
    end
  end
end
