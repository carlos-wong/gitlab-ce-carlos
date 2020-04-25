# frozen_string_literal: true

require 'spec_helper'

describe Repositories::DestroyService do
  let_it_be(:user) { create(:user) }
  let!(:project) { create(:project, :repository, namespace: user.namespace) }
  let(:repository) { project.repository }
  let(:path) { repository.disk_path }
  let(:remove_path) { "#{path}+#{project.id}#{described_class::DELETED_FLAG}" }

  subject { described_class.new(project.repository).execute }

  it 'moves the repository to a +deleted folder' do
    expect(project.gitlab_shell.repository_exists?(project.repository_storage, path + '.git')).to be_truthy
    expect(project.gitlab_shell.repository_exists?(project.repository_storage, remove_path + '.git')).to be_falsey

    subject

    expect(project.gitlab_shell.repository_exists?(project.repository_storage, path + '.git')).to be_falsey
    expect(project.gitlab_shell.repository_exists?(project.repository_storage, remove_path + '.git')).to be_truthy
  end

  it 'schedules the repository deletion' do
    subject

    expect(Repositories::ShellDestroyService).to receive(:new).with(repository).and_call_original

    expect(GitlabShellWorker).to receive(:perform_in)
      .with(Repositories::ShellDestroyService::REPO_REMOVAL_DELAY, :remove_repository, project.repository_storage, remove_path)

    # Because GitlabShellWorker is inside a run_after_commit callback we need to
    # trigger the callback
    project.touch
  end

  it 'removes the repository', :sidekiq_inline do
    subject

    project.touch

    expect(project.gitlab_shell.repository_exists?(project.repository_storage, path + '.git')).to be_falsey
    expect(project.gitlab_shell.repository_exists?(project.repository_storage, remove_path + '.git')).to be_falsey
  end

  it 'flushes the repository cache' do
    expect(repository).to receive(:before_delete)

    subject
  end

  it 'does not perform any action if repository path does not exist and returns success' do
    expect(repository).to receive(:disk_path).and_return('foo')
    expect(repository).not_to receive(:before_delete)

    result = subject

    expect(result[:status]).to eq :success
  end

  context 'when move operation cannot be performed' do
    let(:service) { described_class.new(repository) }

    before do
      allow(service).to receive(:mv_repository).and_return(false)
    end

    it 'returns error' do
      result = service.execute

      expect(result[:status]).to eq :error
    end

    it 'logs the error' do
      expect(Gitlab::AppLogger).to receive(:error)

      service.execute
    end
  end
end
