# frozen_string_literal: true

require 'spec_helper'

describe Projects::DestroyService do
  include ProjectForksHelper

  let_it_be(:user) { create(:user) }
  let!(:project) { create(:project, :repository, namespace: user.namespace) }
  let(:path) { project.repository.disk_path }
  let(:remove_path) { removal_path(path) }
  let(:async) { false } # execute or async_execute

  before do
    stub_container_registry_config(enabled: true)
    stub_container_registry_tags(repository: :any, tags: [])
  end

  shared_examples 'deleting the project' do
    before do
      # Run sidekiq immediately to check that renamed repository will be removed
      destroy_project(project, user, {})
    end

    it 'deletes the project', :sidekiq_inline do
      expect(Project.unscoped.all).not_to include(project)

      expect(project.gitlab_shell.repository_exists?(project.repository_storage, path + '.git')).to be_falsey
      expect(project.gitlab_shell.repository_exists?(project.repository_storage, remove_path + '.git')).to be_falsey
    end
  end

  shared_examples 'deleting the project with pipeline and build' do
    context 'with pipeline and build', :sidekiq_inline do # which has optimistic locking
      let!(:pipeline) { create(:ci_pipeline, project: project) }
      let!(:build) { create(:ci_build, :artifacts, pipeline: pipeline) }

      it_behaves_like 'deleting the project'
    end
  end

  shared_examples 'handles errors thrown during async destroy' do |error_message|
    it 'does not allow the error to bubble up' do
      expect do
        destroy_project(project, user, {})
      end.not_to raise_error
    end

    it 'unmarks the project as "pending deletion"' do
      destroy_project(project, user, {})

      expect(project.reload.pending_delete).to be(false)
    end

    it 'stores an error message in `projects.delete_error`' do
      destroy_project(project, user, {})

      expect(project.reload.delete_error).to be_present
      expect(project.delete_error).to include(error_message)
    end
  end

  it_behaves_like 'deleting the project'

  it 'invalidates personal_project_count cache' do
    expect(user).to receive(:invalidate_personal_projects_count)

    destroy_project(project, user, {})
  end

  context 'when project has remote mirrors' do
    let!(:project) do
      create(:project, :repository, namespace: user.namespace).tap do |project|
        project.remote_mirrors.create(url: 'http://test.com')
      end
    end

    it 'destroys them' do
      expect(RemoteMirror.count).to eq(1)

      destroy_project(project, user, {})

      expect(RemoteMirror.count).to eq(0)
    end
  end

  context 'when project has exports' do
    let!(:project_with_export) do
      create(:project, :repository, namespace: user.namespace).tap do |project|
        create(:import_export_upload,
               project: project,
               export_file: fixture_file_upload('spec/fixtures/project_export.tar.gz'))
      end
    end

    it 'destroys project and export' do
      expect do
        destroy_project(project_with_export, user, {})
      end.to change(ImportExportUpload, :count).by(-1)

      expect(Project.all).not_to include(project_with_export)
    end
  end

  context 'Sidekiq fake' do
    before do
      # Dont run sidekiq to check if renamed repository exists
      Sidekiq::Testing.fake! { destroy_project(project, user, {}) }
    end

    it { expect(Project.all).not_to include(project) }

    it do
      expect(project.gitlab_shell.repository_exists?(project.repository_storage, path + '.git')).to be_falsey
    end

    it do
      expect(project.gitlab_shell.repository_exists?(project.repository_storage, remove_path + '.git')).to be_truthy
    end
  end

  context 'when flushing caches fail due to Git errors' do
    before do
      allow(project.repository).to receive(:before_delete).and_raise(::Gitlab::Git::CommandError)
      allow(Gitlab::GitLogger).to receive(:warn).with(
        class: Repositories::DestroyService.name,
        project_id: project.id,
        disk_path: project.disk_path,
        message: 'Gitlab::Git::CommandError').and_call_original
    end

    it_behaves_like 'deleting the project'
  end

  context 'when flushing caches fail due to Redis' do
    before do
      new_user = create(:user)
      project.team.add_user(new_user, Gitlab::Access::DEVELOPER)
      allow_any_instance_of(described_class).to receive(:flush_caches).and_raise(::Redis::CannotConnectError)
    end

    it 'keeps project team intact upon an error' do
      perform_enqueued_jobs do
        destroy_project(project, user, {})
      rescue ::Redis::CannotConnectError
      end

      expect(project.team.members.count).to eq 2
    end
  end

  context 'with async_execute', :sidekiq_inline do
    let(:async) { true }

    context 'async delete of project with private issue visibility' do
      before do
        project.project_feature.update_attribute("issues_access_level", ProjectFeature::PRIVATE)
      end

      it_behaves_like 'deleting the project'
    end

    it_behaves_like 'deleting the project with pipeline and build'

    context 'errors' do
      context 'when `remove_legacy_registry_tags` fails' do
        before do
          expect_any_instance_of(described_class)
            .to receive(:remove_legacy_registry_tags).and_return(false)
        end

        it_behaves_like 'handles errors thrown during async destroy', "Failed to remove some tags"
      end

      context 'when `remove_repository` fails' do
        before do
          expect_any_instance_of(described_class)
            .to receive(:remove_repository).and_return(false)
        end

        it_behaves_like 'handles errors thrown during async destroy', "Failed to remove project repository"
      end

      context 'when `execute` raises expected error' do
        before do
          expect_any_instance_of(Project)
            .to receive(:destroy!).and_raise(StandardError.new("Other error message"))
        end

        it_behaves_like 'handles errors thrown during async destroy', "Other error message"
      end

      context 'when `execute` raises unexpected error' do
        before do
          expect_any_instance_of(Project)
            .to receive(:destroy!).and_raise(Exception.new('Other error message'))
        end

        it 'allows error to bubble up and rolls back project deletion' do
          expect do
            destroy_project(project, user, {})
          end.to raise_error(Exception, 'Other error message')

          expect(project.reload.pending_delete).to be(false)
          expect(project.delete_error).to include("Other error message")
        end
      end
    end
  end

  describe 'container registry' do
    context 'when there are regular container repositories' do
      let(:container_repository) { create(:container_repository) }

      before do
        stub_container_registry_tags(repository: project.full_path + '/image',
                                     tags: ['tag'])
        project.container_repositories << container_repository
      end

      context 'when image repository deletion succeeds' do
        it 'removes tags' do
          expect_any_instance_of(ContainerRepository)
            .to receive(:delete_tags!).and_return(true)

          destroy_project(project, user)
        end
      end

      context 'when image repository deletion fails' do
        it 'raises an exception' do
          expect_any_instance_of(ContainerRepository)
            .to receive(:delete_tags!).and_raise(RuntimeError)

          expect(destroy_project(project, user)).to be false
        end
      end

      context 'when registry is disabled' do
        before do
          stub_container_registry_config(enabled: false)
        end

        it 'does not attempting to remove any tags' do
          expect(Projects::ContainerRepository::DestroyService).not_to receive(:new)

          destroy_project(project, user)
        end
      end
    end

    context 'when there are tags for legacy root repository' do
      before do
        stub_container_registry_tags(repository: project.full_path,
                                     tags: ['tag'])
      end

      context 'when image repository tags deletion succeeds' do
        it 'removes tags' do
          expect_any_instance_of(ContainerRepository)
            .to receive(:delete_tags!).and_return(true)

          destroy_project(project, user)
        end
      end

      context 'when image repository tags deletion fails' do
        it 'raises an exception' do
          expect_any_instance_of(ContainerRepository)
            .to receive(:delete_tags!).and_return(false)

          expect(destroy_project(project, user)).to be false
        end
      end
    end
  end

  context 'for a forked project with LFS objects' do
    let(:forked_project) { fork_project(project, user) }

    before do
      project.lfs_objects << create(:lfs_object)
      forked_project.reload
    end

    it 'destroys the fork' do
      expect { destroy_project(forked_project, user) }
        .not_to raise_error
    end
  end

  context 'as the root of a fork network' do
    let!(:fork_1) { fork_project(project, user) }
    let!(:fork_2) { fork_project(project, user) }

    it 'updates the fork network with the project name' do
      fork_network = project.fork_network

      destroy_project(project, user)

      fork_network.reload

      expect(fork_network.deleted_root_project_name).to eq(project.full_name)
      expect(fork_network.root_project).to be_nil
    end
  end

  context 'repository +deleted path removal' do
    context 'regular phase' do
      it 'schedules +deleted removal of existing repos' do
        service = described_class.new(project, user, {})
        allow(service).to receive(:schedule_stale_repos_removal)

        expect(Repositories::ShellDestroyService).to receive(:new).and_call_original
        expect(GitlabShellWorker).to receive(:perform_in)
          .with(5.minutes, :remove_repository, project.repository_storage, removal_path(project.disk_path))

        service.execute
      end
    end

    context 'stale cleanup' do
      let(:async) { true }

      it 'schedules +deleted wiki and repo removal' do
        allow(ProjectDestroyWorker).to receive(:perform_async)

        expect(Repositories::ShellDestroyService).to receive(:new).with(project.repository).and_call_original
        expect(GitlabShellWorker).to receive(:perform_in)
          .with(10.minutes, :remove_repository, project.repository_storage, removal_path(project.disk_path))

        expect(Repositories::ShellDestroyService).to receive(:new).with(project.wiki.repository).and_call_original
        expect(GitlabShellWorker).to receive(:perform_in)
          .with(10.minutes, :remove_repository, project.repository_storage, removal_path(project.wiki.disk_path))

        destroy_project(project, user, {})
      end
    end
  end

  def destroy_project(project, user, params = {})
    described_class.new(project, user, params).public_send(async ? :async_execute : :execute)
  end

  def removal_path(path)
    "#{path}+#{project.id}#{Repositories::DestroyService::DELETED_FLAG}"
  end
end
