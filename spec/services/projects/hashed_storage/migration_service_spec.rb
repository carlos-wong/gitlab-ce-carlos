# frozen_string_literal: true

require 'spec_helper'

describe Projects::HashedStorage::MigrationService do
  let(:project) { create(:project, :empty_repo, :wiki_repo, :legacy_storage) }
  let(:logger) { double }

  subject(:service) { described_class.new(project, project.full_path, logger: logger) }

  describe '#execute' do
    context 'repository migration' do
      let(:repository_service) { Projects::HashedStorage::MigrateRepositoryService.new(project, project.full_path, logger: logger) }

      it 'delegates migration to Projects::HashedStorage::MigrateRepositoryService' do
        expect(Projects::HashedStorage::MigrateRepositoryService)
          .to receive(:new)
                .with(project, project.full_path, logger: logger)
                .and_return(repository_service)
        expect(repository_service).to receive(:execute)

        service.execute
      end

      it 'does not delegate migration if repository is already migrated' do
        project.storage_version = ::Project::LATEST_STORAGE_VERSION
        expect(Projects::HashedStorage::MigrateRepositoryService).not_to receive(:new)

        service.execute
      end
    end

    context 'attachments migration' do
      let(:attachments_service) { Projects::HashedStorage::MigrateAttachmentsService.new(project, project.full_path, logger: logger) }

      it 'delegates migration to Projects::HashedStorage::MigrateRepositoryService' do
        expect(Projects::HashedStorage::MigrateAttachmentsService)
          .to receive(:new)
                .with(project, project.full_path, logger: logger)
                .and_return(attachments_service)
        expect(attachments_service).to receive(:execute)

        service.execute
      end

      it 'does not delegate migration if attachments are already migrated' do
        project.storage_version = ::Project::LATEST_STORAGE_VERSION
        expect(Projects::HashedStorage::MigrateAttachmentsService).not_to receive(:new)

        service.execute
      end
    end
  end
end
