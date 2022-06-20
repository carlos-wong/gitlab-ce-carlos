# frozen_string_literal: true

require 'spec_helper'

module Ci
  RSpec.describe RegisterJobService do
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, group: group, shared_runners_enabled: false, group_runners_enabled: false) }
    let_it_be_with_reload(:pipeline) { create(:ci_pipeline, project: project) }

    let!(:shared_runner) { create(:ci_runner, :instance) }
    let!(:specific_runner) { create(:ci_runner, :project, projects: [project]) }
    let!(:group_runner) { create(:ci_runner, :group, groups: [group]) }
    let!(:pending_job) { create(:ci_build, :pending, :queued, pipeline: pipeline) }

    describe '#execute' do
      context 'checks database loadbalancing stickiness' do
        subject { described_class.new(shared_runner).execute }

        before do
          project.update!(shared_runners_enabled: false)
        end

        it 'result is valid if replica did caught-up' do
          expect(ApplicationRecord.sticking).to receive(:all_caught_up?)
            .with(:runner, shared_runner.id) { true }

          expect(subject).to be_valid
        end

        it 'result is invalid if replica did not caught-up' do
          expect(ApplicationRecord.sticking).to receive(:all_caught_up?)
            .with(:runner, shared_runner.id) { false }

          expect(subject).not_to be_valid
        end
      end

      shared_examples 'handles runner assignment' do
        context 'runner follow tag list' do
          it "picks build with the same tag" do
            pending_job.update!(tag_list: ["linux"])
            pending_job.reload
            pending_job.create_queuing_entry!
            specific_runner.update!(tag_list: ["linux"])
            expect(execute(specific_runner)).to eq(pending_job)
          end

          it "does not pick build with different tag" do
            pending_job.update!(tag_list: ["linux"])
            pending_job.reload
            pending_job.create_queuing_entry!
            specific_runner.update!(tag_list: ["win32"])
            expect(execute(specific_runner)).to be_falsey
          end

          it "picks build without tag" do
            expect(execute(specific_runner)).to eq(pending_job)
          end

          it "does not pick build with tag" do
            pending_job.update!(tag_list: ["linux"])
            pending_job.reload
            pending_job.create_queuing_entry!
            expect(execute(specific_runner)).to be_falsey
          end

          it "pick build without tag" do
            specific_runner.update!(tag_list: ["win32"])
            expect(execute(specific_runner)).to eq(pending_job)
          end
        end

        context 'deleted projects' do
          before do
            project.update!(pending_delete: true)
          end

          context 'for shared runners' do
            before do
              project.update!(shared_runners_enabled: true)
            end

            it 'does not pick a build' do
              expect(execute(shared_runner)).to be_nil
            end
          end

          context 'for specific runner' do
            it 'does not pick a build' do
              expect(execute(specific_runner)).to be_nil
              expect(pending_job.reload).to be_failed
              expect(pending_job.queuing_entry).to be_nil
            end
          end
        end

        context 'allow shared runners' do
          before do
            project.update!(shared_runners_enabled: true)
            pipeline.reload
            pending_job.reload
            pending_job.create_queuing_entry!
          end

          context 'when build owner has been blocked' do
            let(:user) { create(:user, :blocked) }

            before do
              pending_job.update!(user: user)
            end

            it 'does not pick the build and drops the build' do
              expect(execute(shared_runner)).to be_falsey

              expect(pending_job.reload).to be_user_blocked
            end
          end

          context 'for multiple builds' do
            let!(:project2) { create :project, shared_runners_enabled: true }
            let!(:pipeline2) { create :ci_pipeline, project: project2 }
            let!(:project3) { create :project, shared_runners_enabled: true }
            let!(:pipeline3) { create :ci_pipeline, project: project3 }
            let!(:build1_project1) { pending_job }
            let!(:build2_project1) { create(:ci_build, :pending, :queued, pipeline: pipeline) }
            let!(:build3_project1) { create(:ci_build, :pending, :queued, pipeline: pipeline) }
            let!(:build1_project2) { create(:ci_build, :pending, :queued, pipeline: pipeline2) }
            let!(:build2_project2) { create(:ci_build, :pending, :queued, pipeline: pipeline2) }
            let!(:build1_project3) { create(:ci_build, :pending, :queued, pipeline: pipeline3) }

            context 'when using fair scheduling' do
              context 'when all builds are pending' do
                it 'prefers projects without builds first' do
                  # it gets for one build from each of the projects
                  expect(execute(shared_runner)).to eq(build1_project1)
                  expect(execute(shared_runner)).to eq(build1_project2)
                  expect(execute(shared_runner)).to eq(build1_project3)

                  # then it gets a second build from each of the projects
                  expect(execute(shared_runner)).to eq(build2_project1)
                  expect(execute(shared_runner)).to eq(build2_project2)

                  # in the end the third build
                  expect(execute(shared_runner)).to eq(build3_project1)
                end
              end

              context 'when some builds transition to success' do
                it 'equalises number of running builds' do
                  # after finishing the first build for project 1, get a second build from the same project
                  expect(execute(shared_runner)).to eq(build1_project1)
                  build1_project1.reload.success
                  expect(execute(shared_runner)).to eq(build2_project1)

                  expect(execute(shared_runner)).to eq(build1_project2)
                  build1_project2.reload.success
                  expect(execute(shared_runner)).to eq(build2_project2)
                  expect(execute(shared_runner)).to eq(build1_project3)
                  expect(execute(shared_runner)).to eq(build3_project1)
                end
              end
            end

            context 'when using DEFCON mode that disables fair scheduling' do
              before do
                stub_feature_flags(ci_queueing_disaster_recovery_disable_fair_scheduling: true)
              end

              context 'when all builds are pending' do
                it 'returns builds in order of creation (FIFO)' do
                  # it gets for one build from each of the projects
                  expect(execute(shared_runner)).to eq(build1_project1)
                  expect(execute(shared_runner)).to eq(build2_project1)
                  expect(execute(shared_runner)).to eq(build3_project1)
                  expect(execute(shared_runner)).to eq(build1_project2)
                  expect(execute(shared_runner)).to eq(build2_project2)
                  expect(execute(shared_runner)).to eq(build1_project3)
                end
              end

              context 'when some builds transition to success' do
                it 'returns builds in order of creation (FIFO)' do
                  expect(execute(shared_runner)).to eq(build1_project1)
                  build1_project1.reload.success
                  expect(execute(shared_runner)).to eq(build2_project1)

                  expect(execute(shared_runner)).to eq(build3_project1)
                  build2_project1.reload.success
                  expect(execute(shared_runner)).to eq(build1_project2)
                  expect(execute(shared_runner)).to eq(build2_project2)
                  expect(execute(shared_runner)).to eq(build1_project3)
                end
              end
            end
          end

          context 'shared runner' do
            let(:response) { described_class.new(shared_runner).execute }
            let(:build) { response.build }

            it { expect(build).to be_kind_of(Build) }
            it { expect(build).to be_valid }
            it { expect(build).to be_running }
            it { expect(build.runner).to eq(shared_runner) }
            it { expect(Gitlab::Json.parse(response.build_json)['id']).to eq(build.id) }
          end

          context 'specific runner' do
            let(:build) { execute(specific_runner) }

            it { expect(build).to be_kind_of(Build) }
            it { expect(build).to be_valid }
            it { expect(build).to be_running }
            it { expect(build.runner).to eq(specific_runner) }
          end
        end

        context 'disallow shared runners' do
          before do
            project.update!(shared_runners_enabled: false)
          end

          context 'shared runner' do
            let(:build) { execute(shared_runner) }

            it { expect(build).to be_nil }
          end

          context 'specific runner' do
            let(:build) { execute(specific_runner) }

            it { expect(build).to be_kind_of(Build) }
            it { expect(build).to be_valid }
            it { expect(build).to be_running }
            it { expect(build.runner).to eq(specific_runner) }
          end
        end

        context 'disallow when builds are disabled' do
          before do
            project.update!(shared_runners_enabled: true, group_runners_enabled: true)
            project.project_feature.update_attribute(:builds_access_level, ProjectFeature::DISABLED)

            pending_job.reload.create_queuing_entry!
          end

          context 'and uses shared runner' do
            let(:build) { execute(shared_runner) }

            it { expect(build).to be_nil }
          end

          context 'and uses group runner' do
            let(:build) { execute(group_runner) }

            it { expect(build).to be_nil }
          end

          context 'and uses project runner' do
            let(:build) { execute(specific_runner) }

            it 'does not pick a build' do
              expect(build).to be_nil
              expect(pending_job.reload).to be_failed
              expect(pending_job.queuing_entry).to be_nil
            end
          end
        end

        context 'allow group runners' do
          before do
            project.update!(group_runners_enabled: true)
          end

          context 'for multiple builds' do
            let!(:project2) { create(:project, group_runners_enabled: true, group: group) }
            let!(:pipeline2) { create(:ci_pipeline, project: project2) }
            let!(:project3) { create(:project, group_runners_enabled: true, group: group) }
            let!(:pipeline3) { create(:ci_pipeline, project: project3) }

            let!(:build1_project1) { pending_job }
            let!(:build2_project1) { create(:ci_build, :queued, pipeline: pipeline) }
            let!(:build3_project1) { create(:ci_build, :queued, pipeline: pipeline) }
            let!(:build1_project2) { create(:ci_build, :queued, pipeline: pipeline2) }
            let!(:build2_project2) { create(:ci_build, :queued, pipeline: pipeline2) }
            let!(:build1_project3) { create(:ci_build, :queued, pipeline: pipeline3) }

            # these shouldn't influence the scheduling
            let!(:unrelated_group) { create(:group) }
            let!(:unrelated_project) { create(:project, group_runners_enabled: true, group: unrelated_group) }
            let!(:unrelated_pipeline) { create(:ci_pipeline, project: unrelated_project) }
            let!(:build1_unrelated_project) { create(:ci_build, :pending, :queued, pipeline: unrelated_pipeline) }
            let!(:unrelated_group_runner) { create(:ci_runner, :group, groups: [unrelated_group]) }

            it 'does not consider builds from other group runners' do
              queue = ::Ci::Queue::BuildQueueService.new(group_runner)

              expect(queue.builds_for_group_runner.size).to eq 6
              execute(group_runner)

              expect(queue.builds_for_group_runner.size).to eq 5
              execute(group_runner)

              expect(queue.builds_for_group_runner.size).to eq 4
              execute(group_runner)

              expect(queue.builds_for_group_runner.size).to eq 3
              execute(group_runner)

              expect(queue.builds_for_group_runner.size).to eq 2
              execute(group_runner)

              expect(queue.builds_for_group_runner.size).to eq 1
              execute(group_runner)

              expect(queue.builds_for_group_runner.size).to eq 0
              expect(execute(group_runner)).to be_nil
            end
          end

          context 'group runner' do
            let(:build) { execute(group_runner) }

            it { expect(build).to be_kind_of(Build) }
            it { expect(build).to be_valid }
            it { expect(build).to be_running }
            it { expect(build.runner).to eq(group_runner) }
          end
        end

        context 'disallow group runners' do
          before do
            project.update!(group_runners_enabled: false)

            pending_job.reload.create_queuing_entry!
          end

          context 'group runner' do
            let(:build) { execute(group_runner) }

            it { expect(build).to be_nil }
          end
        end

        context 'when first build is stalled' do
          before do
            allow_any_instance_of(Ci::RegisterJobService).to receive(:assign_runner!).and_call_original
            allow_any_instance_of(Ci::RegisterJobService).to receive(:assign_runner!)
              .with(pending_job, anything).and_raise(ActiveRecord::StaleObjectError)
          end

          subject { described_class.new(specific_runner).execute }

          context 'with multiple builds are in queue' do
            let!(:other_build) { create(:ci_build, :pending, :queued, pipeline: pipeline) }

            before do
              allow_any_instance_of(::Ci::Queue::BuildQueueService)
                .to receive(:execute)
                .and_return(Ci::Build.where(id: [pending_job, other_build]).pluck(:id))
            end

            it "receives second build from the queue" do
              expect(subject).to be_valid
              expect(subject.build).to eq(other_build)
            end
          end

          context 'when single build is in queue' do
            before do
              allow_any_instance_of(::Ci::Queue::BuildQueueService)
                .to receive(:execute)
                .and_return(Ci::Build.where(id: pending_job).pluck(:id))
            end

            it "does not receive any valid result" do
              expect(subject).not_to be_valid
            end
          end

          context 'when there is no build in queue' do
            before do
              allow_any_instance_of(::Ci::Queue::BuildQueueService)
                .to receive(:execute)
                .and_return([])
            end

            it "does not receive builds but result is valid" do
              expect(subject).to be_valid
              expect(subject.build).to be_nil
            end
          end
        end

        context 'when access_level of runner is not_protected' do
          let!(:specific_runner) { create(:ci_runner, :project, projects: [project]) }

          context 'when a job is protected' do
            let!(:pending_job) { create(:ci_build, :pending, :queued, :protected, pipeline: pipeline) }

            it 'picks the job' do
              expect(execute(specific_runner)).to eq(pending_job)
            end
          end

          context 'when a job is unprotected' do
            let!(:pending_job) { create(:ci_build, :pending, :queued, pipeline: pipeline) }

            it 'picks the job' do
              expect(execute(specific_runner)).to eq(pending_job)
            end
          end

          context 'when protected attribute of a job is nil' do
            let!(:pending_job) { create(:ci_build, :pending, :queued, pipeline: pipeline) }

            before do
              pending_job.update_attribute(:protected, nil)
            end

            it 'picks the job' do
              expect(execute(specific_runner)).to eq(pending_job)
            end
          end
        end

        context 'when access_level of runner is ref_protected' do
          let!(:specific_runner) { create(:ci_runner, :project, :ref_protected, projects: [project]) }

          context 'when a job is protected' do
            let!(:pending_job) { create(:ci_build, :pending, :queued, :protected, pipeline: pipeline) }

            it 'picks the job' do
              expect(execute(specific_runner)).to eq(pending_job)
            end
          end

          context 'when a job is unprotected' do
            let!(:pending_job) { create(:ci_build, :pending, :queued, pipeline: pipeline) }

            it 'does not pick the job' do
              expect(execute(specific_runner)).to be_nil
            end
          end

          context 'when protected attribute of a job is nil' do
            let!(:pending_job) { create(:ci_build, :pending, :queued, pipeline: pipeline) }

            before do
              pending_job.update_attribute(:protected, nil)
            end

            it 'does not pick the job' do
              expect(execute(specific_runner)).to be_nil
            end
          end
        end

        context 'runner feature set is verified' do
          let(:options) { { artifacts: { reports: { junit: "junit.xml" } } } }
          let!(:pending_job) { create(:ci_build, :pending, :queued, pipeline: pipeline, options: options) }

          subject { execute(specific_runner, params) }

          context 'when feature is missing by runner' do
            let(:params) { {} }

            it 'does not pick the build and drops the build' do
              expect(subject).to be_nil
              expect(pending_job.reload).to be_failed
              expect(pending_job).to be_runner_unsupported
            end
          end

          context 'when feature is supported by runner' do
            let(:params) do
              { info: { features: { upload_multiple_artifacts: true } } }
            end

            it 'does pick job' do
              expect(subject).not_to be_nil
            end
          end
        end

        context 'when "dependencies" keyword is specified' do
          shared_examples 'not pick' do
            it 'does not pick the build and drops the build' do
              expect(subject).to be_nil
              expect(pending_job.reload).to be_failed
              expect(pending_job).to be_missing_dependency_failure
            end
          end

          shared_examples 'validation is active' do
            context 'when depended job has not been completed yet' do
              let!(:pre_stage_job) { create(:ci_build, :pending, :queued, :manual, pipeline: pipeline, name: 'test', stage_idx: 0) }

              it { is_expected.to eq(pending_job) }
            end

            context 'when artifacts of depended job has been expired' do
              let!(:pre_stage_job) { create(:ci_build, :success, :expired, pipeline: pipeline, name: 'test', stage_idx: 0) }

              context 'when the pipeline is locked' do
                before do
                  pipeline.artifacts_locked!
                end

                it { is_expected.to eq(pending_job) }
              end

              context 'when the pipeline is unlocked' do
                before do
                  pipeline.unlocked!
                end

                it_behaves_like 'not pick'
              end
            end

            context 'when artifacts of depended job has been erased' do
              let!(:pre_stage_job) { create(:ci_build, :success, pipeline: pipeline, name: 'test', stage_idx: 0, erased_at: 1.minute.ago) }

              before do
                pre_stage_job.erase
              end

              it_behaves_like 'not pick'
            end

            context 'when job object is staled' do
              let!(:pre_stage_job) { create(:ci_build, :success, :expired, pipeline: pipeline, name: 'test', stage_idx: 0) }

              before do
                pipeline.unlocked!

                allow_next_instance_of(Ci::Build) do |build|
                  expect(build).to receive(:drop!)
                    .and_raise(ActiveRecord::StaleObjectError.new(pending_job, :drop!))
                end
              end

              it 'does not drop nor pick' do
                expect(subject).to be_nil
              end
            end
          end

          shared_examples 'validation is not active' do
            context 'when depended job has not been completed yet' do
              let!(:pre_stage_job) { create(:ci_build, :pending, :queued, :manual, pipeline: pipeline, name: 'test', stage_idx: 0) }

              it { expect(subject).to eq(pending_job) }
            end

            context 'when artifacts of depended job has been expired' do
              let!(:pre_stage_job) { create(:ci_build, :success, :expired, pipeline: pipeline, name: 'test', stage_idx: 0) }

              it { expect(subject).to eq(pending_job) }
            end

            context 'when artifacts of depended job has been erased' do
              let!(:pre_stage_job) { create(:ci_build, :success, pipeline: pipeline, name: 'test', stage_idx: 0, erased_at: 1.minute.ago) }

              before do
                pre_stage_job.erase
              end

              it { expect(subject).to eq(pending_job) }
            end
          end

          let!(:pre_stage_job) { create(:ci_build, :success, pipeline: pipeline, name: 'test', stage_idx: 0) }

          let!(:pending_job) do
            create(:ci_build, :pending, :queued,
              pipeline: pipeline, stage_idx: 1,
              options: { script: ["bash"], dependencies: ['test'] })
          end

          subject { execute(specific_runner) }

          it_behaves_like 'validation is active'
        end

        context 'when build is degenerated' do
          let!(:pending_job) { create(:ci_build, :pending, :queued, :degenerated, pipeline: pipeline) }

          subject { execute(specific_runner, {}) }

          it 'does not pick the build and drops the build' do
            expect(subject).to be_nil

            pending_job.reload
            expect(pending_job).to be_failed
            expect(pending_job).to be_archived_failure
          end
        end

        context 'when build has data integrity problem' do
          let!(:pending_job) do
            create(:ci_build, :pending, :queued, pipeline: pipeline)
          end

          before do
            pending_job.update_columns(options: "string")
          end

          subject { execute(specific_runner, {}) }

          it 'does drop the build and logs both failures' do
            expect(Gitlab::ErrorTracking).to receive(:track_exception)
              .with(anything, a_hash_including(build_id: pending_job.id))
              .twice
              .and_call_original

            expect(subject).to be_nil

            pending_job.reload
            expect(pending_job).to be_failed
            expect(pending_job).to be_data_integrity_failure
          end
        end

        context 'when build fails to be run!' do
          let!(:pending_job) do
            create(:ci_build, :pending, :queued, pipeline: pipeline)
          end

          before do
            expect_any_instance_of(Ci::Build).to receive(:run!)
              .and_raise(RuntimeError, 'scheduler error')
          end

          subject { execute(specific_runner, {}) }

          it 'does drop the build and logs failure' do
            expect(Gitlab::ErrorTracking).to receive(:track_exception)
              .with(anything, a_hash_including(build_id: pending_job.id))
              .once
              .and_call_original

            expect(subject).to be_nil

            pending_job.reload
            expect(pending_job).to be_failed
            expect(pending_job).to be_scheduler_failure
          end
        end

        context 'when an exception is raised during a persistent ref creation' do
          before do
            allow_any_instance_of(Ci::PersistentRef).to receive(:exist?) { false }
            allow_any_instance_of(Ci::PersistentRef).to receive(:create_ref) { raise ArgumentError }
          end

          subject { execute(specific_runner, {}) }

          it 'picks the build' do
            expect(subject).to eq(pending_job)

            pending_job.reload
            expect(pending_job).to be_running
          end
        end

        context 'when only some builds can be matched by runner' do
          let!(:specific_runner) { create(:ci_runner, :project, projects: [project], tag_list: %w[matching]) }
          let!(:pending_job) { create(:ci_build, :pending, :queued, pipeline: pipeline, tag_list: %w[matching]) }

          before do
            # create additional matching and non-matching jobs
            create_list(:ci_build, 2, :pending, :queued, pipeline: pipeline, tag_list: %w[matching])
            create(:ci_build, :pending, :queued, pipeline: pipeline, tag_list: %w[non-matching])
          end

          it 'observes queue size of only matching jobs' do
            # pending_job + 2 x matching ones
            expect(Gitlab::Ci::Queue::Metrics.queue_size_total).to receive(:observe)
              .with({ runner_type: specific_runner.runner_type }, 3)

            expect(execute(specific_runner)).to eq(pending_job)
          end

          it 'observes queue processing time by the runner type' do
            expect(Gitlab::Ci::Queue::Metrics.queue_iteration_duration_seconds)
              .to receive(:observe)
              .with({ runner_type: specific_runner.runner_type }, anything)

            expect(Gitlab::Ci::Queue::Metrics.queue_retrieval_duration_seconds)
              .to receive(:observe)
              .with({ runner_type: specific_runner.runner_type }, anything)

            expect(execute(specific_runner)).to eq(pending_job)
          end
        end

        context 'when ci_register_job_temporary_lock is enabled' do
          before do
            stub_feature_flags(ci_register_job_temporary_lock: true)

            allow(Gitlab::Ci::Queue::Metrics.queue_operations_total).to receive(:increment)
          end

          context 'when a build is temporarily locked' do
            let(:service) { described_class.new(specific_runner) }

            before do
              service.send(:acquire_temporary_lock, pending_job.id)
            end

            it 'skips this build and marks queue as invalid' do
              expect(Gitlab::Ci::Queue::Metrics.queue_operations_total).to receive(:increment)
                .with(operation: :queue_iteration)
              expect(Gitlab::Ci::Queue::Metrics.queue_operations_total).to receive(:increment)
                .with(operation: :build_temporary_locked)

              expect(service.execute).not_to be_valid
            end

            context 'when there is another build in queue' do
              let!(:next_pending_job) { create(:ci_build, :pending, :queued, pipeline: pipeline) }

              it 'skips this build and picks another build' do
                expect(Gitlab::Ci::Queue::Metrics.queue_operations_total).to receive(:increment)
                  .with(operation: :queue_iteration).twice
                expect(Gitlab::Ci::Queue::Metrics.queue_operations_total).to receive(:increment)
                  .with(operation: :build_temporary_locked)

                result = service.execute

                expect(result.build).to eq(next_pending_job)
                expect(result).to be_valid
              end
            end
          end
        end
      end

      context 'when a long queue is created' do
        it 'picks builds one-by-one' do
          expect(Ci::Build).to receive(:find).with(pending_job.id).and_call_original

          expect(execute(specific_runner)).to eq(pending_job)
        end

        include_examples 'handles runner assignment'
      end

      context 'when using pending builds table' do
        before do
          stub_feature_flags(ci_pending_builds_queue_source: true)
        end

        context 'with ci_queuing_use_denormalized_data_strategy enabled' do
          before do
            stub_feature_flags(ci_queuing_use_denormalized_data_strategy: true)
          end

          include_examples 'handles runner assignment'
        end

        context 'with ci_queuing_use_denormalized_data_strategy disabled' do
          before do
            skip_if_multiple_databases_are_setup

            stub_feature_flags(ci_queuing_use_denormalized_data_strategy: false)
          end

          around do |example|
            allow_cross_joins_across_databases(url: 'https://gitlab.com/gitlab-org/gitlab/-/issues/332952') do
              example.run
            end
          end

          include_examples 'handles runner assignment'
        end

        context 'with ci_queuing_use_denormalized_data_strategy enabled' do
          before do
            stub_feature_flags(ci_queuing_use_denormalized_data_strategy: true)
          end

          include_examples 'handles runner assignment'
        end

        context 'when a conflicting data is stored in denormalized table' do
          let!(:specific_runner) { create(:ci_runner, :project, projects: [project], tag_list: %w[conflict]) }
          let!(:pending_job) { create(:ci_build, :pending, :queued, pipeline: pipeline, tag_list: %w[conflict]) }

          before do
            pending_job.update_column(:status, :running)
          end

          it 'removes queuing entry upon build assignment attempt' do
            expect(pending_job.reload).to be_running
            expect(pending_job.queuing_entry).to be_present

            result = described_class.new(specific_runner).execute

            expect(result).not_to be_valid
            expect(pending_job.reload.queuing_entry).not_to be_present
          end
        end
      end

      context 'when not using pending builds table' do
        before do
          skip_if_multiple_databases_are_setup

          stub_feature_flags(ci_pending_builds_queue_source: false)
        end

        around do |example|
          allow_cross_joins_across_databases(url: 'https://gitlab.com/gitlab-org/gitlab/-/issues/332952') do
            example.run
          end
        end

        include_examples 'handles runner assignment'
      end
    end

    describe '#register_success' do
      let!(:current_time) { Time.zone.local(2018, 4, 5, 14, 0, 0) }
      let!(:attempt_counter) { double('Gitlab::Metrics::NullMetric') }
      let!(:job_queue_duration_seconds) { double('Gitlab::Metrics::NullMetric') }

      before do
        allow(Time).to receive(:now).and_return(current_time)
        # Stub tested metrics
        allow(Gitlab::Ci::Queue::Metrics)
          .to receive(:attempt_counter)
          .and_return(attempt_counter)

        allow(Gitlab::Ci::Queue::Metrics)
          .to receive(:job_queue_duration_seconds)
          .and_return(job_queue_duration_seconds)

        project.update!(shared_runners_enabled: true)
        pending_job.update!(created_at: current_time - 3600, queued_at: current_time - 1800)
      end

      shared_examples 'attempt counter collector' do
        it 'increments attempt counter' do
          allow(job_queue_duration_seconds).to receive(:observe)
          expect(attempt_counter).to receive(:increment)

          execute(runner)
        end
      end

      shared_examples 'jobs queueing time histogram collector' do
        it 'counts job queuing time histogram with expected labels' do
          allow(attempt_counter).to receive(:increment)
          expect(job_queue_duration_seconds).to receive(:observe)
            .with({ shared_runner: expected_shared_runner,
                    jobs_running_for_project: expected_jobs_running_for_project_first_job,
                    shard: expected_shard }, 1800)

          execute(runner)
        end

        context 'when project already has running jobs' do
          let(:build2) { create(:ci_build, :running, pipeline: pipeline, runner: shared_runner) }
          let(:build3) { create(:ci_build, :running, pipeline: pipeline, runner: shared_runner) }

          before do
            ::Ci::RunningBuild.upsert_shared_runner_build!(build2)
            ::Ci::RunningBuild.upsert_shared_runner_build!(build3)
          end

          it 'counts job queuing time histogram with expected labels' do
            allow(attempt_counter).to receive(:increment)

            expect(job_queue_duration_seconds).to receive(:observe)
              .with({ shared_runner: expected_shared_runner,
                      jobs_running_for_project: expected_jobs_running_for_project_third_job,
                      shard: expected_shard }, 1800)

            execute(runner)
          end
        end
      end

      shared_examples 'metrics collector' do
        it_behaves_like 'attempt counter collector'
        it_behaves_like 'jobs queueing time histogram collector'

        context 'when using denormalized data is disabled' do
          before do
            stub_feature_flags(ci_pending_builds_maintain_denormalized_data: false)
          end

          it_behaves_like 'jobs queueing time histogram collector'
        end
      end

      context 'when shared runner is used' do
        before do
          pending_job.reload
          pending_job.create_queuing_entry!
        end

        let(:runner) { create(:ci_runner, :instance, tag_list: %w(tag1 tag2)) }
        let(:expected_shared_runner) { true }
        let(:expected_shard) { ::Gitlab::Ci::Queue::Metrics::DEFAULT_METRICS_SHARD }
        let(:expected_jobs_running_for_project_first_job) { 0 }
        let(:expected_jobs_running_for_project_third_job) { 2 }

        it_behaves_like 'metrics collector'

        context 'when metrics_shard tag is defined' do
          let(:runner) { create(:ci_runner, :instance, tag_list: %w(tag1 metrics_shard::shard_tag tag2)) }
          let(:expected_shard) { 'shard_tag' }

          it_behaves_like 'metrics collector'
        end

        context 'when multiple metrics_shard tag is defined' do
          let(:runner) { create(:ci_runner, :instance, tag_list: %w(tag1 metrics_shard::shard_tag metrics_shard::shard_tag_2 tag2)) }
          let(:expected_shard) { 'shard_tag' }

          it_behaves_like 'metrics collector'
        end

        context 'when max running jobs bucket size is exceeded' do
          before do
            stub_const('Gitlab::Ci::Queue::Metrics::JOBS_RUNNING_FOR_PROJECT_MAX_BUCKET', 1)
          end

          let(:expected_jobs_running_for_project_third_job) { '1+' }

          it_behaves_like 'metrics collector'
        end

        context 'when pending job with queued_at=nil is used' do
          before do
            pending_job.update!(queued_at: nil)
          end

          it_behaves_like 'attempt counter collector'

          it "doesn't count job queuing time histogram" do
            allow(attempt_counter).to receive(:increment)
            expect(job_queue_duration_seconds).not_to receive(:observe)

            execute(runner)
          end
        end
      end

      context 'when specific runner is used' do
        let(:runner) { create(:ci_runner, :project, projects: [project], tag_list: %w(tag1 metrics_shard::shard_tag tag2)) }
        let(:expected_shared_runner) { false }
        let(:expected_shard) { ::Gitlab::Ci::Queue::Metrics::DEFAULT_METRICS_SHARD }
        let(:expected_jobs_running_for_project_first_job) { '+Inf' }
        let(:expected_jobs_running_for_project_third_job) { '+Inf' }

        it_behaves_like 'metrics collector'
      end
    end

    context 'when runner_session params are' do
      it 'present sets runner session configuration in the build' do
        runner_session_params = { session: { 'url' => 'https://example.com' } }

        expect(execute(specific_runner, runner_session_params).runner_session.attributes)
          .to include(runner_session_params[:session])
      end

      it 'not present it does not configure the runner session' do
        expect(execute(specific_runner).runner_session).to be_nil
      end
    end

    context 'when max queue depth is reached' do
      let!(:pending_job) { create(:ci_build, :pending, :queued, :degenerated, pipeline: pipeline) }
      let!(:pending_job_2) { create(:ci_build, :pending, :queued, :degenerated, pipeline: pipeline) }
      let!(:pending_job_3) { create(:ci_build, :pending, :queued, pipeline: pipeline) }

      before do
        stub_const("#{described_class}::MAX_QUEUE_DEPTH", 2)
      end

      it 'returns 409 conflict' do
        expect(Ci::Build.pending.unstarted.count).to eq 3

        result = described_class.new(specific_runner).execute

        expect(result).not_to be_valid
        expect(result.build).to be_nil
      end
    end

    def execute(runner, params = {})
      described_class.new(runner).execute(params).build
    end
  end
end
