# frozen_string_literal: true

require 'spec_helper'

describe Groups::ImportExport::ExportService do
  describe '#execute' do
    let!(:user) { create(:user) }
    let(:group) { create(:group) }
    let(:shared) { Gitlab::ImportExport::Shared.new(group) }
    let(:archive_path) { shared.archive_path }
    let(:service) { described_class.new(group: group, user: user, params: { shared: shared }) }

    before do
      group.add_owner(user)
    end

    after do
      FileUtils.rm_rf(archive_path)
    end

    it 'saves the models' do
      expect(Gitlab::ImportExport::Group::TreeSaver).to receive(:new).and_call_original

      service.execute
    end

    context 'when saver succeeds' do
      it 'saves the group in the file system' do
        service.execute

        expect(group.import_export_upload.export_file.file).not_to be_nil
        expect(File.directory?(archive_path)).to eq(false)
        expect(File.exist?(shared.archive_path)).to eq(false)
      end
    end

    context 'when user does not have admin_group permission' do
      let!(:another_user) { create(:user) }
      let(:service) { described_class.new(group: group, user: another_user, params: { shared: shared }) }

      let(:expected_message) do
        "User with ID: %s does not have required permissions for Group: %s with ID: %s" %
          [another_user.id, group.name, group.id]
      end

      it 'fails' do
        expect { service.execute }.to raise_error(Gitlab::ImportExport::Error).with_message(expected_message)
      end

      it 'logs the error' do
        expect(shared.logger).to receive(:error).with(
          group_id:   group.id,
          group_name: group.name,
          error:      expected_message,
          message:    'Group Import/Export: Export failed'
        )

        expect { service.execute }.to raise_error(Gitlab::ImportExport::Error)
      end

      it 'tracks the error' do
        expect(shared).to receive(:error) { |param| expect(param.message).to eq expected_message }

        expect { service.execute }.to raise_error(Gitlab::ImportExport::Error)
      end
    end

    context 'when export fails' do
      context 'when file saver fails' do
        it 'removes the remaining exported data' do
          allow_next_instance_of(Gitlab::ImportExport::Saver) do |saver|
            allow(saver).to receive(:save).and_return(false)
          end

          expect { service.execute }.to raise_error(Gitlab::ImportExport::Error)

          expect(group.import_export_upload).to be_nil
          expect(File.exist?(shared.archive_path)).to eq(false)
        end
      end

      context 'when file compression fails' do
        before do
          allow(service).to receive_message_chain(:tree_exporter, :save).and_return(false)
        end

        it 'removes the remaining exported data' do
          allow_next_instance_of(Gitlab::ImportExport::Saver) do |saver|
            allow(saver).to receive(:compress_and_save).and_return(false)
          end

          expect { service.execute }.to raise_error(Gitlab::ImportExport::Error)

          expect(group.import_export_upload).to be_nil
          expect(File.exist?(shared.archive_path)).to eq(false)
        end

        it 'notifies logger' do
          allow(service).to receive_message_chain(:tree_exporter, :save).and_return(false)
          expect(shared.logger).to receive(:error)

          expect { service.execute }.to raise_error(Gitlab::ImportExport::Error)
        end
      end
    end
  end
end
