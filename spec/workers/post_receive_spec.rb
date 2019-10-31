# frozen_string_literal: true

require 'spec_helper'

describe PostReceive do
  let(:changes) { "123456 789012 refs/heads/tést\n654321 210987 refs/tags/tag" }
  let(:wrongly_encoded_changes) { changes.encode("ISO-8859-1").force_encoding("UTF-8") }
  let(:base64_changes) { Base64.encode64(wrongly_encoded_changes) }
  let(:gl_repository) { "project-#{project.id}" }
  let(:key) { create(:key, user: project.owner) }
  let!(:key_id) { key.shell_id }

  let(:project) do
    create(:project, :repository, auto_cancel_pending_pipelines: 'disabled')
  end

  def perform(changes: base64_changes)
    described_class.new.perform(gl_repository, key_id, changes)
  end

  context "as a sidekiq worker" do
    it "responds to #perform" do
      expect(described_class.new).to respond_to(:perform)
    end
  end

  context 'with a non-existing project' do
    let(:gl_repository) { "project-123456789" }
    let(:error_message) do
      "Triggered hook for non-existing project with gl_repository \"#{gl_repository}\""
    end

    it "returns false and logs an error" do
      expect(Gitlab::GitLogger).to receive(:error).with("POST-RECEIVE: #{error_message}")
      expect(perform).to be(false)
    end
  end

  describe "#process_project_changes" do
    context 'with an empty project' do
      let(:empty_project) { create(:project, :empty_repo) }
      let(:changes) { "123456 789012 refs/heads/tést1\n" }

      before do
        allow_any_instance_of(Gitlab::GitPostReceive).to receive(:identify).and_return(empty_project.owner)
        # Need to mock here so we can expect calls on project
        allow(Gitlab::GlRepository).to receive(:parse).and_return([empty_project, Gitlab::GlRepository::PROJECT])
      end

      it 'expire the status cache' do
        expect(empty_project.repository).to receive(:expire_status_cache)

        perform
      end

      it 'schedules a cache update for commit count and size' do
        expect(ProjectCacheWorker).to receive(:perform_async)
                                        .with(empty_project.id, [], [:repository_size, :commit_count], true)

        perform
      end
    end

    shared_examples 'not updating remote mirrors' do
      it 'does not schedule an update' do
        expect(project).not_to receive(:has_remote_mirror?)
        expect(project).not_to receive(:mark_stuck_remote_mirrors_as_failed!)
        expect(project).not_to receive(:update_remote_mirrors)

        perform
      end
    end

    context 'empty changes' do
      it "does not call any PushService but runs after project hooks" do
        expect(Git::ProcessRefChangesService).not_to receive(:new)
        expect_next_instance_of(SystemHooksService) { |service| expect(service).to receive(:execute_hooks) }

        perform(changes: "")
      end

      it_behaves_like 'not updating remote mirrors'
    end

    context 'unidentified user' do
      let!(:key_id) { "" }

      it 'returns false' do
        expect(Git::ProcessRefChangesService).not_to receive(:new)

        expect(perform).to be false
      end
    end

    context 'with changes' do
      let(:push_service) { double(execute: true) }

      before do
        allow_any_instance_of(Gitlab::GitPostReceive).to receive(:identify).and_return(project.owner)
        allow(Gitlab::GlRepository).to receive(:parse).and_return([project, Gitlab::GlRepository::PROJECT])
      end

      shared_examples 'updating remote mirrors' do
        it 'schedules an update if the project had mirrors' do
          expect(project).to receive(:has_remote_mirror?).and_return(true)
          expect(project).to receive(:mark_stuck_remote_mirrors_as_failed!)
          expect(project).to receive(:update_remote_mirrors)

          perform
        end
      end

      context "branches" do
        let(:changes) do
          <<~EOF
            123456 789012 refs/heads/tést1
            123456 789012 refs/heads/tést2
          EOF
        end

        it 'expires the branches cache' do
          expect(project.repository).to receive(:expire_branches_cache).once

          perform
        end

        it 'expires the status cache' do
          expect(project.repository).to receive(:empty?).and_return(true)
          expect(project.repository).to receive(:expire_status_cache)

          perform
        end

        it 'calls Git::ProcessRefChangesService' do
          expect_next_instance_of(Git::ProcessRefChangesService) do |service|
            expect(service).to receive(:execute).and_return(true)
          end

          perform
        end

        it 'schedules a cache update for repository size only' do
          expect(ProjectCacheWorker).to receive(:perform_async)
                                          .with(project.id, [], [:repository_size], true)

          perform
        end

        it_behaves_like 'updating remote mirrors'

        context 'with a default branch' do
          let(:changes) do
            <<~EOF
              123456 789012 refs/heads/tést1
              123456 789012 refs/heads/tést2
              678912 123455 refs/heads/#{project.default_branch}
            EOF
          end

          it 'schedules a cache update for commit count and size' do
            expect(ProjectCacheWorker).to receive(:perform_async)
                                            .with(project.id, [], [:repository_size, :commit_count], true)

            perform
          end
        end
      end

      context "tags" do
        let(:changes) do
          <<~EOF
            654321 210987 refs/tags/tag1
            654322 210986 refs/tags/tag2
            654323 210985 refs/tags/tag3
          EOF
        end

        before do
          expect(Gitlab::GlRepository).to receive(:parse).and_return([project, Gitlab::GlRepository::PROJECT])
        end

        it 'does not expire branches cache' do
          expect(project.repository).not_to receive(:expire_branches_cache)

          perform
        end

        it 'only invalidates tags once' do
          expect(project.repository).to receive(:repository_event).exactly(3).times.with(:push_tag).and_call_original
          expect(project.repository).to receive(:expire_caches_for_tags).once.and_call_original
          expect(project.repository).to receive(:expire_tags_cache).once.and_call_original

          perform
        end

        it 'calls Git::ProcessRefChangesService' do
          expect_next_instance_of(Git::ProcessRefChangesService) do |service|
            expect(service).to receive(:execute).and_return(true)
          end

          perform
        end

        it 'schedules a single ProjectCacheWorker update' do
          expect(ProjectCacheWorker).to receive(:perform_async)
                                          .with(project.id, [], [:repository_size], true)

          perform
        end

        it_behaves_like 'updating remote mirrors'
      end

      context "merge-requests" do
        let(:changes) { "123456 789012 refs/merge-requests/123" }

        it "does not call any of the services" do
          expect(Git::ProcessRefChangesService).not_to receive(:new)

          perform
        end

        it_behaves_like 'not updating remote mirrors'
      end

      context 'after project changes hooks' do
        let(:changes) { '123456 789012 refs/heads/tést' }
        let(:fake_hook_data) { Hash.new(event_name: 'repository_update') }

        before do
          allow_any_instance_of(Gitlab::DataBuilder::Repository).to receive(:update).and_return(fake_hook_data)
          # silence hooks so we can isolate
          allow_any_instance_of(Key).to receive(:post_create_hook).and_return(true)
          expect_next_instance_of(Git::ProcessRefChangesService) do |service|
            expect(service).to receive(:execute).and_return(true)
          end
        end

        it 'calls SystemHooksService' do
          expect_any_instance_of(SystemHooksService).to receive(:execute_hooks).with(fake_hook_data, :repository_update_hooks).and_return(true)

          perform
        end

        it 'increments the usage data counter of pushes event' do
          counter = Gitlab::UsageDataCounters::SourceCodeCounter

          expect { perform }.to change { counter.read(:pushes) }.by(1)
        end
      end
    end
  end

  describe '#process_wiki_changes' do
    let(:gl_repository) { "wiki-#{project.id}" }

    before do
      # Need to mock here so we can expect calls on project
      allow(Gitlab::GlRepository).to receive(:parse).and_return([project, Gitlab::GlRepository::WIKI])
    end

    it 'updates project activity' do
      # Force Project#set_timestamps_for_create to initialize timestamps
      project

      # MySQL drops milliseconds in the timestamps, so advance at least
      # a second to ensure we see changes.
      Timecop.freeze(1.second.from_now) do
        expect do
          perform
          project.reload
        end.to change(project, :last_activity_at)
           .and change(project, :last_repository_updated_at)
      end
    end

    context "branches" do
      let(:changes) do
        <<~EOF
            123456 789012 refs/heads/tést1
            123456 789012 refs/heads/tést2
        EOF
      end

      it 'expires the branches cache' do
        expect(project.wiki.repository).to receive(:expire_branches_cache).once

        perform
      end

      it 'expires the status cache' do
        expect(project.wiki.repository).to receive(:empty?).and_return(true)
        expect(project.wiki.repository).to receive(:expire_status_cache)

        perform
      end
    end
  end

  context "webhook" do
    it "fetches the correct project" do
      expect(Project).to receive(:find_by).with(id: project.id.to_s)

      perform
    end

    it "does not run if the author is not in the project" do
      allow_any_instance_of(Gitlab::GitPostReceive)
        .to receive(:identify_using_ssh_key)
        .and_return(nil)

      expect(project).not_to receive(:execute_hooks)

      expect(perform).to be_falsey
    end

    it "asks the project to trigger all hooks" do
      create(:project_hook, push_events: true, tag_push_events: true, project: project)
      create(:custom_issue_tracker_service, push_events: true, merge_requests_events: false, project: project)
      allow(Project).to receive(:find_by).and_return(project)

      expect(project).to receive(:execute_hooks).twice
      expect(project).to receive(:execute_services).twice

      perform
    end

    it "enqueues a UpdateMergeRequestsWorker job" do
      allow(Project).to receive(:find_by).and_return(project)

      expect(UpdateMergeRequestsWorker).to receive(:perform_async).with(project.id, project.owner.id, any_args)

      perform
    end
  end
end
