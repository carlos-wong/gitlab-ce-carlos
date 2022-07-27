# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::DestroyService, :aggregate_failures, :event_store_publisher do
  include ProjectForksHelper

  let_it_be(:user) { create(:user) }

  let!(:project) { create(:project, :repository, namespace: user.namespace) }
  let(:path) { project.repository.disk_path }
  let(:async) { false } # execute or async_execute

  before do
    stub_container_registry_config(enabled: true)
    stub_container_registry_tags(repository: :any, tags: [])
  end

  shared_examples 'deleting the project' do
    it 'deletes the project', :sidekiq_inline do
      destroy_project(project, user, {})

      expect(Project.unscoped.all).not_to include(project)

      expect(project.gitlab_shell.repository_exists?(project.repository_storage, path + '.git')).to be_falsey
    end

    it 'publishes a ProjectDeletedEvent' do
      expected_data = {
        project_id: project.id,
        namespace_id: project.namespace_id,
        root_namespace_id: project.root_namespace.id
      }

      expect { destroy_project(project, user, {}) }.to publish_event(Projects::ProjectDeletedEvent).with(expected_data)
    end
  end

  shared_examples 'deleting the project with pipeline and build' do
    context 'with pipeline and build related records', :sidekiq_inline do # which has optimistic locking
      let!(:pipeline) { create(:ci_pipeline, project: project) }
      let!(:build) { create(:ci_build, :artifacts, :with_runner_session, pipeline: pipeline) }
      let!(:trace_chunks) { create(:ci_build_trace_chunk, build: build) }
      let!(:job_variables) { create(:ci_job_variable, job: build) }
      let!(:report_result) { create(:ci_build_report_result, build: build) }
      let!(:pending_state) { create(:ci_build_pending_state, build: build) }
      let!(:pipeline_artifact) { create(:ci_pipeline_artifact, pipeline: pipeline) }
      let!(:secure_file) { create(:ci_secure_file, project: project) }

      it 'deletes build and pipeline related records' do
        expect { destroy_project(project, user, {}) }
          .to  change { Ci::Build.count }.by(-1)
          .and change { Ci::BuildTraceChunk.count }.by(-1)
          .and change { Ci::JobArtifact.count }.by(-2)
          .and change { Ci::DeletedObject.count }.by(2)
          .and change { Ci::PipelineArtifact.count }.by(-1)
          .and change { Ci::JobVariable.count }.by(-1)
          .and change { Ci::BuildPendingState.count }.by(-1)
          .and change { Ci::BuildReportResult.count }.by(-1)
          .and change { Ci::BuildRunnerSession.count }.by(-1)
          .and change { Ci::Pipeline.count }.by(-1)
          .and change { Ci::SecureFile.count }.by(-1)
      end

      it 'avoids N+1 queries' do
        recorder = ActiveRecord::QueryRecorder.new { destroy_project(project, user, {}) }

        project = create(:project, :repository, namespace: user.namespace)
        pipeline = create(:ci_pipeline, project: project)
        builds = create_list(:ci_build, 3, :artifacts, pipeline: pipeline)
        create(:ci_pipeline_artifact, pipeline: pipeline)
        create_list(:ci_build_trace_chunk, 3, build: builds[0])

        expect { destroy_project(project, project.first_owner, {}) }.not_to exceed_query_limit(recorder)
      end

      it_behaves_like 'deleting the project'

      context 'when project is undergoing refresh' do
        let!(:build_artifacts_size_refresh) { create(:project_build_artifacts_size_refresh, :pending, project: project) }

        it 'does not log about artifact deletion but continues to delete artifacts' do
          expect(Gitlab::ProjectStatsRefreshConflictsLogger).not_to receive(:warn_artifact_deletion_during_stats_refresh)

          expect { destroy_project(project, user, {}) }
            .to change { Ci::JobArtifact.count }.by(-2)
            .and change { Projects::BuildArtifactsSizeRefresh.count }.by(-1)
        end
      end
    end
  end

  shared_examples 'handles errors thrown during async destroy' do |error_message|
    it 'does not allow the error to bubble up' do
      expect do
        destroy_project(project, user, {})
      end.not_to raise_error
    end

    it 'reports the error' do
      expect(Gitlab::ErrorTracking).to receive(:track_exception).and_call_original
      destroy_project(project, user, {})
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

  context "deleting a project with merge requests" do
    let!(:merge_request) { create(:merge_request, source_project: project) }

    before do
      allow(project).to receive(:destroy!).and_return(true)
    end

    [MergeRequestDiffCommit, MergeRequestDiffFile].each do |model|
      it "deletes #{model} records of the merge request" do
        merge_request_diffs = merge_request.merge_request_diffs
        expect(merge_request_diffs.size).to eq(1)

        records_count = model.where(merge_request_diff_id: merge_request_diffs.first.id).count

        expect { destroy_project(project, user, {}) }.to change { model.count }.by(-records_count)
      end
    end
  end

  it_behaves_like 'deleting the project'

  it 'invalidates personal_project_count cache' do
    expect(user).to receive(:invalidate_personal_projects_count)

    destroy_project(project, user, {})
  end

  context 'with running pipelines' do
    let!(:pipelines)               { create_list(:ci_pipeline, 3, :running, project: project) }
    let(:destroy_pipeline_service) { double('DestroyPipelineService', execute: nil) }

    it 'bulks-fails with AbortPipelineService and then executes DestroyPipelineService for each pipelines' do
      allow(::Ci::DestroyPipelineService).to receive(:new).and_return(destroy_pipeline_service)

      expect(::Ci::AbortPipelinesService)
        .to receive_message_chain(:new, :execute)
        .with(project.all_pipelines, :project_deleted)

      pipelines.each do |pipeline|
        expect(destroy_pipeline_service).to receive(:execute).with(pipeline)
      end

      destroy_project(project, user, {})
    end
  end

  context 'when project has remote mirrors' do
    let!(:project) do
      create(:project, :repository, namespace: user.namespace).tap do |project|
        project.remote_mirrors.create!(url: 'http://test.com')
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
  end

  context 'when flushing caches fail due to Git errors' do
    before do
      allow(project.repository).to receive(:before_delete).and_raise(::Gitlab::Git::CommandError)
      allow(Gitlab::GitLogger).to receive(:warn).with(
        class: Repositories::DestroyService.name,
        container_id: project.id,
        disk_path: project.disk_path,
        message: 'Gitlab::Git::CommandError').and_call_original
    end

    it_behaves_like 'deleting the project'
  end

  context 'when flushing caches fail due to Redis' do
    before do
      new_user = create(:user)
      project.team.add_member(new_user, Gitlab::Access::DEVELOPER)
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

    context 'for an archived project' do
      before do
        project.update!(archived: true)
      end

      it_behaves_like 'deleting the project with pipeline and build'
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

  context 'repository removal' do
    it 'removal of existing repos' do
      expect_next_instances_of(Repositories::DestroyService, 2) do |instance|
        expect(instance).to receive(:execute).and_return(status: :success)
      end

      described_class.new(project, user, {}).execute
    end
  end

  context 'snippets' do
    let!(:snippet1) { create(:project_snippet, project: project, author: user) }
    let!(:snippet2) { create(:project_snippet, project: project, author: user) }

    it 'does not include snippets when deleting in batches' do
      expect(project).to receive(:destroy_dependent_associations_in_batches).with({ exclude: [:container_repositories, :snippets] })

      destroy_project(project, user)
    end

    it 'calls the bulk snippet destroy service with the hard_delete param set to true' do
      expect(project.snippets.count).to eq 2

      expect_next_instance_of(Snippets::BulkDestroyService, user, project.snippets) do |instance|
        expect(instance).to receive(:execute).with(hard_delete: true).and_call_original
      end

      expect do
        destroy_project(project, user)
      end.to change(Snippet, :count).by(-2)
    end

    context 'when an error is raised deleting snippets' do
      let(:error_message) { 'foo' }

      it 'does not delete project' do
        allow_next_instance_of(Snippets::BulkDestroyService) do |instance|
          allow(instance).to receive(:execute).and_return(ServiceResponse.error(message: error_message))
        end

        expect(Gitlab::AppLogger).to receive(:error).with("Snippet deletion failed on #{project.full_path} with the following message: #{error_message}")
        expect(Gitlab::AppLogger).to receive(:error).with(/Failed to remove project snippets/)
        expect(destroy_project(project, user)).to be_falsey
        expect(project.gitlab_shell.repository_exists?(project.repository_storage, path + '.git')).to be_truthy
      end
    end
  end

  context 'when project has webhooks' do
    let!(:web_hook1) { create(:project_hook, project: project) }
    let!(:web_hook2) { create(:project_hook, project: project) }
    let!(:another_project_web_hook) { create(:project_hook) }
    let!(:web_hook_log) { create(:web_hook_log, web_hook: web_hook1) }

    it 'deletes webhooks and logs related to project' do
      expect_next_instance_of(WebHooks::DestroyService, user) do |instance|
        expect(instance).to receive(:execute).with(web_hook1).and_call_original
      end
      expect_next_instance_of(WebHooks::DestroyService, user) do |instance|
        expect(instance).to receive(:execute).with(web_hook2).and_call_original
      end

      expect do
        destroy_project(project, user)
      end.to change(WebHook, :count).by(-2)
    end

    context 'when an error is raised deleting webhooks' do
      before do
        allow_next_instance_of(WebHooks::DestroyService) do |instance|
          allow(instance).to receive(:execute).and_return(message: 'foo', status: :error)
        end
      end

      it_behaves_like 'handles errors thrown during async destroy', "Failed to remove webhooks"
    end
  end

  context 'when project has project bots' do
    let!(:project_bot) { create(:user, :project_bot).tap { |user| project.add_maintainer(user) } }

    it 'deletes bot user as well' do
      expect do
        destroy_project(project, user)
      end.to change { User.find_by(id: project_bot.id) }.to(nil)
    end
  end

  context 'when project has events' do
    let!(:event) { create(:event, :created, project: project, target: project, author: user) }

    it 'deletes events from the project' do
      expect do
        destroy_project(project, user)
      end.to change(Event, :count).by(-1)
    end

    context 'when an error is returned while deleting events' do
      it 'does not delete project' do
        allow_next_instance_of(Events::DestroyService) do |instance|
          allow(instance).to receive(:execute).and_return(ServiceResponse.error(message: 'foo'))
        end

        expect(destroy_project(project, user)).to be_falsey
        expect(project.delete_error).to include('Failed to remove events')
      end
    end
  end

  context 'error while destroying', :sidekiq_inline do
    let!(:pipeline) { create(:ci_pipeline, project: project) }
    let!(:builds) { create_list(:ci_build, 2, :artifacts, pipeline: pipeline) }
    let!(:build_trace) { create(:ci_build_trace_chunk, build: builds[0]) }

    it 'deletes on retry' do
      # We can expect this to timeout for very large projects
      # TODO: remove allow_next_instance_of: https://gitlab.com/gitlab-org/gitlab/-/issues/220440
      allow_any_instance_of(Ci::Build).to receive(:destroy).and_raise('boom')
      destroy_project(project, user, {})

      allow_any_instance_of(Ci::Build).to receive(:destroy).and_call_original
      destroy_project(project, user, {})

      expect(Project.unscoped.all).not_to include(project)
      expect(project.gitlab_shell.repository_exists?(project.repository_storage, path + '.git')).to be_falsey
      expect(project.all_pipelines).to be_empty
      expect(project.builds).to be_empty
    end
  end

  def destroy_project(project, user, params = {})
    described_class.new(project, user, params).public_send(async ? :async_execute : :execute)
  end
end
