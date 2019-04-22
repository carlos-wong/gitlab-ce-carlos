# frozen_string_literal: true

require 'spec_helper'

describe ProjectDestroyWorker do
  let(:project) { create(:project, :repository, pending_delete: true) }
  let(:path) do
    Gitlab::GitalyClient::StorageSettings.allow_disk_access do
      project.repository.path_to_repo
    end
  end

  subject { described_class.new }

  describe '#perform' do
    it 'deletes the project' do
      subject.perform(project.id, project.owner.id, {})

      expect(Project.all).not_to include(project)
      expect(Dir.exist?(path)).to be_falsey
    end

    it 'does not raise error when project could not be found' do
      expect do
        subject.perform(-1, project.owner.id, {})
      end.not_to raise_error
    end

    it 'does not raise error when user could not be found' do
      expect do
        subject.perform(project.id, -1, {})
      end.not_to raise_error
    end
  end
end
