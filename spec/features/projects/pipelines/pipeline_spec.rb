# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Pipeline', :js do
  include RoutesHelpers
  include ProjectForksHelper
  include ::ExclusiveLeaseHelpers

  let_it_be(:project) { create(:project) }

  let(:user) { create(:user) }
  let(:role) { :developer }

  before do
    sign_in(user)
    project.add_role(user, role)
    stub_feature_flags(pipeline_tabs_vue: false)
  end

  shared_context 'pipeline builds' do
    let!(:build_passed) do
      create(:ci_build, :success,
             pipeline: pipeline, stage: 'build', stage_idx: 0, name: 'build')
    end

    let!(:build_failed) do
      create(:ci_build, :failed,
             pipeline: pipeline, stage: 'test', stage_idx: 1, name: 'test')
    end

    let!(:build_preparing) do
      create(:ci_build, :preparing,
             pipeline: pipeline, stage: 'deploy', stage_idx: 2, name: 'prepare')
    end

    let!(:build_running) do
      create(:ci_build, :running,
             pipeline: pipeline, stage: 'deploy', stage_idx: 3, name: 'deploy')
    end

    let!(:build_manual) do
      create(:ci_build, :manual,
             pipeline: pipeline, stage: 'deploy', stage_idx: 3, name: 'manual-build')
    end

    let!(:build_scheduled) do
      create(:ci_build, :scheduled,
             pipeline: pipeline, stage: 'deploy', stage_idx: 3, name: 'delayed-job')
    end

    let!(:build_external) do
      create(:generic_commit_status, status: 'success',
                                     pipeline: pipeline,
                                     name: 'jenkins',
                                     stage: 'external',
                                     ref: 'master',
                                     target_url: 'http://gitlab.com/status')
    end
  end

  describe 'GET /:project/-/pipelines/:id' do
    include_context 'pipeline builds'

    let_it_be(:group) { create(:group) }
    let_it_be(:project, reload: true) { create(:project, :repository, group: group) }

    let(:pipeline) { create(:ci_pipeline, project: project, ref: 'master', sha: project.commit.id, user: user) }

    subject(:visit_pipeline) { visit project_pipeline_path(project, pipeline) }

    it 'shows the pipeline graph' do
      visit_pipeline

      expect(page).to have_selector('.js-pipeline-graph')
      expect(page).to have_content('Build')
      expect(page).to have_content('Test')
      expect(page).to have_content('Deploy')
      expect(page).to have_content('Retry')
      expect(page).to have_content('Cancel running')
    end

    it 'shows Pipeline tab pane as active' do
      visit_pipeline

      expect(page).to have_css('#js-tab-pipeline.active')
    end

    it 'shows link to the pipeline ref' do
      visit_pipeline

      expect(page).to have_link(pipeline.ref)
    end

    it 'shows the pipeline information' do
      visit_pipeline

      within '.pipeline-info' do
        expect(page).to have_content("#{pipeline.statuses.count} jobs " \
                                      "for #{pipeline.ref}")
        expect(page).to have_link(pipeline.ref,
          href: project_commits_path(pipeline.project, pipeline.ref))
      end
    end

    describe 'related merge requests' do
      context 'when there are no related merge requests' do
        it 'shows a "no related merge requests" message' do
          visit_pipeline

          within '.related-merge-request-info' do
            expect(page).to have_content('No related merge requests found.')
          end
        end
      end

      context 'when there is one related merge request' do
        let!(:merge_request) do
          create(:merge_request,
            source_project: project,
            source_branch: pipeline.ref)
        end

        it 'shows a link to the merge request' do
          visit_pipeline

          within '.related-merge-requests' do
            expect(page).to have_content('1 related merge request: ')
            expect(page).to have_selector('.js-truncated-mr-list')
            expect(page).to have_link("#{merge_request.to_reference} #{merge_request.title}")

            expect(page).not_to have_selector('.js-full-mr-list')
            expect(page).not_to have_selector('.text-expander')
          end
        end
      end

      context 'when there are two related merge requests' do
        let!(:merge_request1) do
          create(:merge_request,
            source_project: project,
            source_branch: pipeline.ref)
        end

        let!(:merge_request2) do
          create(:merge_request,
            source_project: project,
            source_branch: pipeline.ref,
            target_branch: 'fix')
        end

        it 'links to the most recent related merge request' do
          visit_pipeline

          within '.related-merge-requests' do
            expect(page).to have_content('2 related merge requests: ')
            expect(page).to have_link("#{merge_request2.to_reference} #{merge_request2.title}")
            expect(page).to have_selector('.text-expander')
            expect(page).to have_selector('.js-full-mr-list', visible: false)
          end
        end

        it 'expands to show links to all related merge requests' do
          visit_pipeline

          within '.related-merge-requests' do
            find('.text-expander').click

            expect(page).to have_selector('.js-full-mr-list', visible: true)

            pipeline.all_merge_requests.map do |merge_request|
              expect(page).to have_link(href: project_merge_request_path(project, merge_request))
            end
          end
        end
      end
    end

    describe 'pipelines details view' do
      let!(:status) { create(:user_status, user: pipeline.user, emoji: 'smirk', message: 'Authoring this object') }

      it 'pipeline header shows the user status and emoji' do
        visit project_pipeline_path(project, pipeline)

        within '[data-testid="ci-header-content"]' do
          expect(page).to have_selector("[data-testid='#{status.message}']")
          expect(page).to have_selector("[data-name='#{status.emoji}']")
        end
      end
    end

    describe 'pipeline graph' do
      before do
        visit_pipeline
      end

      context 'when pipeline has running builds' do
        it 'shows a running icon and a cancel action for the running build' do
          page.within('#ci-badge-deploy') do
            expect(page).to have_selector('.js-ci-status-icon-running')
            expect(page).to have_selector('.js-icon-cancel')
            expect(page).to have_content('deploy')
          end
        end

        it 'cancels the running build and shows retry button', :sidekiq_might_not_need_inline do
          find('#ci-badge-deploy .ci-action-icon-container').click

          page.within('#ci-badge-deploy') do
            expect(page).to have_css('.js-icon-retry')
          end
        end
      end

      context 'when pipeline has preparing builds' do
        it 'shows a preparing icon and a cancel action' do
          page.within('#ci-badge-prepare') do
            expect(page).to have_selector('.js-ci-status-icon-preparing')
            expect(page).to have_selector('.js-icon-cancel')
            expect(page).to have_content('prepare')
          end
        end

        it 'cancels the preparing build and shows retry button', :sidekiq_might_not_need_inline do
          find('#ci-badge-deploy .ci-action-icon-container').click

          page.within('#ci-badge-deploy') do
            expect(page).to have_css('.js-icon-retry')
          end
        end
      end

      context 'when pipeline has successful builds' do
        it 'shows the success icon and a retry action for the successful build' do
          page.within('#ci-badge-build') do
            expect(page).to have_selector('.js-ci-status-icon-success')
            expect(page).to have_content('build')
          end

          page.within('#ci-badge-build .ci-action-icon-container.js-icon-retry') do
            expect(page).to have_selector('svg')
          end
        end

        it 'is possible to retry the success job', :sidekiq_might_not_need_inline do
          find('#ci-badge-build .ci-action-icon-container').click
          wait_for_requests

          expect(page).not_to have_content('Retry job')
          within('.js-pipeline-header-container') do
            expect(page).to have_selector('.js-ci-status-icon-running')
          end
        end
      end

      context 'when pipeline has a delayed job' do
        let(:project) { create(:project, :repository, group: group) }

        it 'shows the scheduled icon and an unschedule action for the delayed job' do
          page.within('#ci-badge-delayed-job') do
            expect(page).to have_selector('.js-ci-status-icon-scheduled')
            expect(page).to have_content('delayed-job')
          end

          page.within('#ci-badge-delayed-job .ci-action-icon-container.js-icon-time-out') do
            expect(page).to have_selector('svg')
          end
        end

        it 'unschedules the delayed job and shows play button as a manual job', :sidekiq_might_not_need_inline do
          find('#ci-badge-delayed-job .ci-action-icon-container').click

          page.within('#ci-badge-delayed-job') do
            expect(page).to have_css('.js-icon-play')
          end
        end
      end

      context 'when pipeline has failed builds' do
        it 'shows the failed icon and a retry action for the failed build' do
          page.within('#ci-badge-test') do
            expect(page).to have_selector('.js-ci-status-icon-failed')
            expect(page).to have_content('test')
          end

          page.within('#ci-badge-test .ci-action-icon-container.js-icon-retry') do
            expect(page).to have_selector('svg')
          end
        end

        it 'is possible to retry the failed build', :sidekiq_might_not_need_inline do
          find('#ci-badge-test .ci-action-icon-container').click
          wait_for_requests

          expect(page).not_to have_content('Retry job')
          within('.js-pipeline-header-container') do
            expect(page).to have_selector('.js-ci-status-icon-running')
          end
        end

        it 'includes the failure reason' do
          page.within('#ci-badge-test') do
            build_link = page.find('.js-pipeline-graph-job-link')
            expect(build_link['title']).to eq('test - failed - (unknown failure)')
          end
        end
      end

      context 'when pipeline has manual jobs' do
        it 'shows the skipped icon and a play action for the manual build' do
          page.within('#ci-badge-manual-build') do
            expect(page).to have_selector('.js-ci-status-icon-manual')
            expect(page).to have_content('manual')
          end

          page.within('#ci-badge-manual-build .ci-action-icon-container.js-icon-play') do
            expect(page).to have_selector('svg')
          end
        end

        it 'is possible to play the manual job', :sidekiq_might_not_need_inline do
          find('#ci-badge-manual-build .ci-action-icon-container').click
          wait_for_requests

          expect(page).not_to have_content('Play job')
          within('.js-pipeline-header-container') do
            expect(page).to have_selector('.js-ci-status-icon-running')
          end
        end
      end

      context 'when pipeline has external job' do
        it 'shows the success icon and the generic comit status build' do
          expect(page).to have_selector('.js-ci-status-icon-success')
          expect(page).to have_content('jenkins')
          expect(page).to have_link('jenkins', href: 'http://gitlab.com/status')
        end
      end
    end

    context 'when the pipeline has manual stage' do
      before do
        create(:ci_build, :manual, pipeline: pipeline, stage_idx: 10, stage: 'publish', name: 'CentOS')
        create(:ci_build, :manual, pipeline: pipeline, stage_idx: 10, stage: 'publish', name: 'Debian')
        create(:ci_build, :manual, pipeline: pipeline, stage_idx: 10, stage: 'publish', name: 'OpenSUDE')

        # force to update stages statuses
        Ci::ProcessPipelineService.new(pipeline).execute

        visit_pipeline
      end

      it 'displays play all button' do
        expect(page).to have_selector('.js-stage-action')
      end
    end

    context 'page tabs' do
      before do
        stub_feature_flags(pipeline_tabs_vue: false)
        visit_pipeline
      end

      it 'shows Pipeline, Jobs, DAG and Failed Jobs tabs with link' do
        expect(page).to have_link('Pipeline')
        expect(page).to have_link('Jobs')
        expect(page).to have_link('Needs')
        expect(page).to have_link('Failed Jobs')
      end

      it 'shows counter in Jobs tab' do
        expect(page.find('.js-builds-counter').text).to eq(pipeline.total_size.to_s)
      end

      it 'shows Pipeline tab as active' do
        expect(page).to have_css('.js-pipeline-tab-link .active')
      end

      context 'without permission to access builds' do
        let(:project) { create(:project, :public, :repository, public_builds: false) }
        let(:role) { :guest }

        it 'does not show the pipeline details page' do
          expect(page).to have_content('Not Found')
        end
      end
    end

    describe 'test tabs' do
      let(:pipeline) { create(:ci_pipeline, :with_test_reports, :with_report_results, project: project) }

      before do
        stub_feature_flags(pipeline_tabs_vue: false)
        visit_pipeline
        wait_for_requests
      end

      context 'with test reports' do
        it 'shows badge counter in Tests tab' do
          expect(page.find('.js-test-report-badge-counter').text).to eq(pipeline.test_report_summary.total[:count].to_s)
        end

        it 'calls summary.json endpoint', :js do
          find('.js-tests-tab-link').click

          expect(page).to have_content('Jobs')
          expect(page).to have_selector('[data-testid="tests-detail"]', visible: :all)
        end
      end

      context 'without test reports' do
        let(:pipeline) { create(:ci_pipeline, project: project) }

        it 'shows zero' do
          expect(page.find('.js-test-report-badge-counter', visible: :all).text).to eq("0")
        end
      end
    end

    context 'retrying jobs' do
      before do
        visit_pipeline
      end

      it { expect(page).not_to have_content('retried') }

      context 'when retrying' do
        before do
          find('[data-testid="retryPipeline"]').click
          wait_for_requests
        end

        it 'does not show a "Retry" button', :sidekiq_might_not_need_inline do
          expect(page).not_to have_content('Retry')
        end

        it 'shows running status in pipeline header', :sidekiq_might_not_need_inline do
          within('.js-pipeline-header-container') do
            expect(page).to have_selector('.js-ci-status-icon-running')
          end
        end
      end
    end

    context 'canceling jobs' do
      before do
        visit_pipeline
      end

      it { expect(page).not_to have_selector('.ci-canceled') }

      context 'when canceling' do
        before do
          click_on 'Cancel running'
        end

        it 'does not show a "Cancel running" button', :sidekiq_might_not_need_inline do
          expect(page).not_to have_content('Cancel running')
        end
      end
    end

    context 'when user can not delete' do
      before do
        visit_pipeline
      end

      it { expect(page).not_to have_button('Delete') }
    end

    context 'when deleting' do
      before do
        group.add_owner(user)

        visit_pipeline

        click_button 'Delete'
        click_button 'Delete pipeline'
      end

      it 'redirects to pipeline overview page', :sidekiq_inline do
        expect(page).to have_content('The pipeline has been deleted')
        expect(page).to have_current_path(project_pipelines_path(project), ignore_query: true)
      end
    end

    context 'when pipeline ref does not exist in repository anymore' do
      let(:pipeline) do
        create(:ci_empty_pipeline, project: project,
                                   ref: 'non-existent',
                                   sha: project.commit.id,
                                   user: user)
      end

      before do
        visit_pipeline
      end

      it 'does not render link to the pipeline ref' do
        expect(page).not_to have_link(pipeline.ref)
        expect(page).to have_content(pipeline.ref)
      end

      it 'does not render render raw HTML to the pipeline ref' do
        page.within '.pipeline-info' do
          expect(page).not_to have_content('<span class="ref-name"')
        end
      end
    end

    context 'when pipeline is detached merge request pipeline' do
      let(:source_project) { project }
      let(:target_project) { project }

      let(:merge_request) do
        create(:merge_request,
          :with_detached_merge_request_pipeline,
          source_project: source_project,
          target_project: target_project)
      end

      let(:pipeline) do
        merge_request.all_pipelines.last
      end

      it 'shows the pipeline information' do
        visit_pipeline

        within '.pipeline-info' do
          expect(page).to have_content("#{pipeline.statuses.count} jobs " \
                                       "for !#{merge_request.iid} " \
                                       "with #{merge_request.source_branch}")
          expect(page).to have_link("!#{merge_request.iid}",
            href: project_merge_request_path(project, merge_request))
          expect(page).to have_link(merge_request.source_branch,
            href: project_commits_path(merge_request.source_project, merge_request.source_branch))
        end
      end

      context 'when source branch does not exist' do
        before do
          project.repository.rm_branch(user, merge_request.source_branch)
        end

        it 'does not link to the source branch commit path' do
          visit_pipeline

          within '.pipeline-info' do
            expect(page).not_to have_link(merge_request.source_branch)
            expect(page).to have_content(merge_request.source_branch)
          end
        end
      end

      context 'when source project is a forked project' do
        let(:source_project) { fork_project(project, user, repository: true) }

        before do
          visit project_pipeline_path(source_project, pipeline)
        end

        it 'shows the pipeline information', :sidekiq_might_not_need_inline do
          within '.pipeline-info' do
            expect(page).to have_content("#{pipeline.statuses.count} jobs " \
                                         "for !#{merge_request.iid} " \
                                         "with #{merge_request.source_branch}")
            expect(page).to have_link("!#{merge_request.iid}",
              href: project_merge_request_path(project, merge_request))
            expect(page).to have_link(merge_request.source_branch,
              href: project_commits_path(merge_request.source_project, merge_request.source_branch))
          end
        end
      end
    end

    context 'when pipeline is merge request pipeline' do
      let(:project) { create(:project, :repository, group: group) }
      let(:source_project) { project }
      let(:target_project) { project }

      let(:merge_request) do
        create(:merge_request,
          :with_merge_request_pipeline,
          source_project: source_project,
          target_project: target_project,
          merge_sha: project.commit.id)
      end

      let(:pipeline) do
        merge_request.all_pipelines.last
      end

      before do
        pipeline.update!(user: user)
      end

      it 'shows the pipeline information' do
        visit_pipeline

        within '.pipeline-info' do
          expect(page).to have_content("#{pipeline.statuses.count} jobs " \
                                       "for !#{merge_request.iid} " \
                                       "with #{merge_request.source_branch} " \
                                       "into #{merge_request.target_branch}")
          expect(page).to have_link("!#{merge_request.iid}",
            href: project_merge_request_path(project, merge_request))
          expect(page).to have_link(merge_request.source_branch,
            href: project_commits_path(merge_request.source_project, merge_request.source_branch))
          expect(page).to have_link(merge_request.target_branch,
            href: project_commits_path(merge_request.target_project, merge_request.target_branch))
        end
      end

      context 'when target branch does not exist' do
        before do
          project.repository.rm_branch(user, merge_request.target_branch)
        end

        it 'does not link to the target branch commit path' do
          visit_pipeline

          within '.pipeline-info' do
            expect(page).not_to have_link(merge_request.target_branch)
            expect(page).to have_content(merge_request.target_branch)
          end
        end
      end

      context 'when source project is a forked project' do
        let(:source_project) { fork_project(project, user, repository: true) }

        before do
          visit project_pipeline_path(source_project, pipeline)
        end

        it 'shows the pipeline information', :sidekiq_might_not_need_inline do
          within '.pipeline-info' do
            expect(page).to have_content("#{pipeline.statuses.count} jobs " \
                                       "for !#{merge_request.iid} " \
                                       "with #{merge_request.source_branch} " \
                                       "into #{merge_request.target_branch}")
            expect(page).to have_link("!#{merge_request.iid}",
              href: project_merge_request_path(project, merge_request))
            expect(page).to have_link(merge_request.source_branch,
              href: project_commits_path(merge_request.source_project, merge_request.source_branch))
            expect(page).to have_link(merge_request.target_branch,
              href: project_commits_path(merge_request.target_project, merge_request.target_branch))
          end
        end
      end
    end
  end

  context 'when user does not have access to read jobs' do
    before do
      project.update!(public_builds: false)
    end

    describe 'GET /:project/-/pipelines/:id' do
      include_context 'pipeline builds'

      let_it_be(:project) { create(:project, :repository) }

      let(:pipeline) { create(:ci_pipeline, project: project, ref: 'master', sha: project.commit.id, user: user) }

      before do
        visit project_pipeline_path(project, pipeline)
      end

      it 'shows the pipeline graph' do
        expect(page).to have_selector('.js-pipeline-graph')
        expect(page).to have_content('Build')
        expect(page).to have_content('Test')
        expect(page).to have_content('Deploy')
        expect(page).to have_content('Retry')
        expect(page).to have_content('Cancel running')
      end

      it 'does not link to job' do
        expect(page).not_to have_selector('.js-pipeline-graph-job-link')
      end
    end
  end

  context 'when a bridge job exists' do
    include_context 'pipeline builds'

    let(:project) { create(:project, :repository) }
    let(:downstream) { create(:project, :repository) }

    let(:pipeline) do
      create(:ci_pipeline, project: project,
                           ref: 'master',
                           sha: project.commit.id,
                           user: user)
    end

    let!(:bridge) do
      create(:ci_bridge, pipeline: pipeline,
                         name: 'cross-build',
                         user: user,
                         downstream: downstream)
    end

    describe 'GET /:project/-/pipelines/:id' do
      before do
        visit project_pipeline_path(project, pipeline)
      end

      it 'shows the pipeline with a bridge job' do
        expect(page).to have_selector('.js-pipeline-graph')
        expect(page).to have_content('cross-build')
      end

      context 'when a scheduled pipeline is created by a blocked user' do
        let(:project)  { create(:project, :repository) }

        let(:schedule) do
          create(:ci_pipeline_schedule,
            project: project,
            owner: project.first_owner,
            description: 'blocked user schedule'
          ).tap do |schedule|
            schedule.update_column(:next_run_at, 1.minute.ago)
          end
        end

        before do
          schedule.owner.block!

          begin
            PipelineScheduleWorker.new.perform
          rescue Ci::CreatePipelineService::CreateError
            # Do nothing, assert view code after the Pipeline failed to create.
          end
        end

        it 'displays the PipelineSchedule in an inactive state' do
          visit project_pipeline_schedules_path(project)
          page.click_link('Inactive')

          expect(page).to have_selector('table.ci-table > tbody > tr > td', text: 'blocked user schedule')
        end

        it 'does not create a new Pipeline' do
          visit project_pipelines_path(project)

          expect(page).not_to have_selector('.ci-table')
          expect(schedule.last_pipeline).to be_nil
        end
      end
    end

    describe 'GET /:project/-/pipelines/:id/builds' do
      before do
        visit builds_project_pipeline_path(project, pipeline)
      end

      it 'shows a bridge job on a list' do
        expect(page).to have_content('cross-build')
        expect(page).to have_content(bridge.id)
      end
    end
  end

  context 'when build requires resource', :sidekiq_inline do
    let_it_be(:project) { create(:project, :repository) }

    let(:pipeline) { create(:ci_pipeline, project: project) }
    let(:resource_group) { create(:ci_resource_group, project: project) }

    let!(:test_job) do
      create(:ci_build, :pending, stage: 'test', name: 'test',
        stage_idx: 1, pipeline: pipeline, project: project)
    end

    let!(:deploy_job) do
      create(:ci_build, :created, stage: 'deploy', name: 'deploy',
        stage_idx: 2, pipeline: pipeline, project: project, resource_group: resource_group)
    end

    describe 'GET /:project/-/pipelines/:id' do
      subject { visit project_pipeline_path(project, pipeline) }

      it 'shows deploy job as created' do
        subject

        within('.js-pipeline-header-container') do
          expect(page).to have_content('pending')
        end

        within('.js-pipeline-graph') do
          within(all('[data-testid="stage-column"]')[0]) do
            expect(page).to have_content('test')
            expect(page).to have_css('.ci-status-icon-pending')
          end

          within(all('[data-testid="stage-column"]')[1]) do
            expect(page).to have_content('deploy')
            expect(page).to have_css('.ci-status-icon-created')
          end
        end
      end

      context 'when test job succeeded' do
        before do
          test_job.success!
        end

        it 'shows deploy job as pending' do
          subject

          within('.js-pipeline-header-container') do
            expect(page).to have_content('running')
          end

          within('.js-pipeline-graph') do
            within(all('[data-testid="stage-column"]')[0]) do
              expect(page).to have_content('test')
              expect(page).to have_css('.ci-status-icon-success')
            end

            within(all('[data-testid="stage-column"]')[1]) do
              expect(page).to have_content('deploy')
              expect(page).to have_css('.ci-status-icon-pending')
            end
          end
        end
      end

      context 'when test job succeeded but there are no available resources' do
        let(:another_job) { create(:ci_build, :running, project: project, resource_group: resource_group) }

        before do
          resource_group.assign_resource_to(another_job)
          test_job.success!
        end

        it 'shows deploy job as waiting for resource' do
          subject

          within('.js-pipeline-header-container') do
            expect(page).to have_content('waiting')
          end

          within('.js-pipeline-graph') do
            within(all('[data-testid="stage-column"]')[1]) do
              expect(page).to have_content('deploy')
              expect(page).to have_css('.ci-status-icon-waiting-for-resource')
            end
          end
        end

        context 'when resource is released from another job' do
          before do
            another_job.success!
          end

          it 'shows deploy job as pending' do
            subject

            within('.js-pipeline-header-container') do
              expect(page).to have_content('running')
            end

            within('.js-pipeline-graph') do
              within(all('[data-testid="stage-column"]')[1]) do
                expect(page).to have_content('deploy')
                expect(page).to have_css('.ci-status-icon-pending')
              end
            end
          end
        end

        context 'when deploy job is a bridge to trigger a downstream pipeline' do
          let!(:deploy_job) do
            create(:ci_bridge, :created, stage: 'deploy', name: 'deploy',
              stage_idx: 2, pipeline: pipeline, project: project, resource_group: resource_group)
          end

          it 'shows deploy job as waiting for resource' do
            subject

            within('.js-pipeline-header-container') do
              expect(page).to have_content('waiting')
            end

            within('.js-pipeline-graph') do
              within(all('[data-testid="stage-column"]')[1]) do
                expect(page).to have_content('deploy')
                expect(page).to have_css('.ci-status-icon-waiting-for-resource')
              end
            end
          end
        end

        context 'when deploy job is a bridge to trigger a downstream pipeline' do
          let!(:deploy_job) do
            create(:ci_bridge, :created, stage: 'deploy', name: 'deploy',
              stage_idx: 2, pipeline: pipeline, project: project, resource_group: resource_group)
          end

          it 'shows deploy job as waiting for resource' do
            subject

            within('.js-pipeline-header-container') do
              expect(page).to have_content('waiting')
            end

            within('.js-pipeline-graph') do
              within(all('[data-testid="stage-column"]')[1]) do
                expect(page).to have_content('deploy')
                expect(page).to have_css('.ci-status-icon-waiting-for-resource')
              end
            end
          end
        end
      end
    end
  end

  describe 'GET /:project/-/pipelines/:id/builds' do
    include_context 'pipeline builds'

    let_it_be(:project) { create(:project, :repository) }

    let(:pipeline) { create(:ci_pipeline, project: project, ref: 'master', sha: project.commit.id) }

    before do
      stub_feature_flags(pipeline_tabs_vue: false)
      visit builds_project_pipeline_path(project, pipeline)
    end

    it 'shows a list of jobs' do
      expect(page).to have_content('Test')
      expect(page).to have_content(build_passed.id)
      expect(page).to have_content('Deploy')
      expect(page).to have_content(build_failed.id)
      expect(page).to have_content(build_running.id)
      expect(page).to have_content(build_external.id)
      expect(page).to have_content('Retry')
      expect(page).to have_content('Cancel running')
      expect(page).to have_button('Play')
    end

    it 'shows jobs tab pane as active' do
      expect(page).to have_css('#js-tab-builds.active')
    end

    context 'page tabs' do
      before do
        stub_feature_flags(pipeline_tabs_vue: false)
      end

      it 'shows Pipeline, Jobs and DAG tabs with link' do
        expect(page).to have_link('Pipeline')
        expect(page).to have_link('Jobs')
        expect(page).to have_link('Needs')
      end

      it 'shows counter in Jobs tab' do
        expect(page.find('.js-builds-counter').text).to eq(pipeline.total_size.to_s)
      end

      it 'shows Jobs tab as active' do
        expect(page).to have_css('li.js-builds-tab-link .active')
      end
    end

    context 'retrying jobs' do
      it { expect(page).not_to have_content('retried') }

      context 'when retrying' do
        before do
          find('[data-testid="retry"]', match: :first).click
        end

        it 'does not show a "Retry" button', :sidekiq_might_not_need_inline do
          expect(page).not_to have_content('Retry')
        end
      end
    end

    context 'canceling jobs' do
      it { expect(page).not_to have_selector('.ci-canceled') }

      context 'when canceling' do
        before do
          click_on 'Cancel running'
        end

        it 'does not show a "Cancel running" button', :sidekiq_might_not_need_inline do
          expect(page).not_to have_content('Cancel running')
        end
      end
    end

    context 'playing manual job' do
      before do
        within '[data-testid="jobs-tab-table"]' do
          click_button('Play')

          wait_for_requests
        end
      end

      it { expect(build_manual.reload).to be_pending }
    end

    context 'when user unschedules a delayed job' do
      before do
        within '[data-testid="jobs-tab-table"]' do
          click_button('Unschedule')
        end
      end

      it 'unschedules the delayed job and shows play button as a manual job' do
        expect(page).to have_button('Play')
        expect(page).not_to have_button('Unschedule')
      end
    end
  end

  describe 'GET /:project/-/pipelines/:id/failures' do
    before do
      stub_feature_flags(pipeline_tabs_vue: false)
    end

    let(:pipeline) { create(:ci_pipeline, project: project, ref: 'master', sha: '1234') }
    let(:pipeline_failures_page) { failures_project_pipeline_path(project, pipeline) }
    let!(:failed_build) { create(:ci_build, :failed, pipeline: pipeline) }

    subject { visit pipeline_failures_page }

    context 'with failed build' do
      before do
        failed_build.trace.set('4 examples, 1 failure')
      end

      it 'shows jobs tab pane as active' do
        subject

        expect(page).to have_content('Failed Jobs')
        expect(page).to have_css('#js-tab-failures.active')
      end

      it 'lists failed builds' do
        subject

        expect(page).to have_content(failed_build.name)
        expect(page).to have_content(failed_build.stage)
      end

      it 'shows build failure logs' do
        subject

        expect(page).to have_content('4 examples, 1 failure')
      end

      it 'shows the failure reason' do
        subject

        expect(page).to have_content('There is an unknown failure, please try again')
      end

      context 'when user does not have permission to retry build' do
        it 'shows retry button for failed build' do
          subject

          page.within(find('.build-failures', match: :first)) do
            expect(page).not_to have_link('Retry')
          end
        end
      end

      context 'when user does have permission to retry build' do
        before do
          create(:protected_branch, :developers_can_merge,
                 name: pipeline.ref, project: project)
        end

        it 'shows retry button for failed build' do
          subject

          page.within(find('.build-failures', match: :first)) do
            expect(page).to have_link('Retry')
          end
        end
      end
    end

    context 'when missing build logs' do
      it 'shows jobs tab pane as active' do
        subject

        expect(page).to have_content('Failed Jobs')
        expect(page).to have_css('#js-tab-failures.active')
      end

      it 'lists failed builds' do
        subject

        expect(page).to have_content(failed_build.name)
        expect(page).to have_content(failed_build.stage)
      end

      it 'does not show log' do
        subject

        expect(page).to have_content('No job log')
      end
    end

    context 'without permission to access builds' do
      let(:role) { :guest }

      before do
        project.update!(public_builds: false)
      end

      context 'when accessing failed jobs page' do
        it 'renders a 404 page' do
          requests = inspect_requests { subject }

          expect(page).to have_title('Not Found')
          expect(requests.first.status_code).to eq(404)
        end
      end
    end

    context 'without failures' do
      before do
        failed_build.update!(status: :success)
      end

      it 'displays the pipeline graph' do
        subject

        expect(page).to have_current_path(pipeline_path(pipeline), ignore_query: true)
        expect(page).not_to have_content('Failed Jobs')
        expect(page).to have_selector('.js-pipeline-graph')
      end
    end
  end

  describe 'GET /:project/-/pipelines/:id/dag' do
    include_context 'pipeline builds'

    let_it_be(:project) { create(:project, :repository) }

    let(:pipeline) { create(:ci_pipeline, project: project, ref: 'master', sha: project.commit.id) }

    before do
      stub_feature_flags(pipeline_tabs_vue: false)
      visit dag_project_pipeline_path(project, pipeline)
    end

    it 'shows DAG tab pane as active' do
      expect(page).to have_css('#js-tab-dag.active', visible: false)
    end

    context 'page tabs' do
      it 'shows Pipeline, Jobs and DAG tabs with link' do
        expect(page).to have_link('Pipeline')
        expect(page).to have_link('Jobs')
        expect(page).to have_link('DAG')
      end

      it 'shows counter in Jobs tab' do
        expect(page.find('.js-builds-counter').text).to eq(pipeline.total_size.to_s)
      end

      it 'shows DAG tab as active' do
        expect(page).to have_css('li.js-dag-tab-link .active')
      end
    end
  end

  context 'when user sees pipeline flags in a pipeline detail page' do
    let_it_be(:project) { create(:project, :repository) }

    context 'when pipeline is latest' do
      include_context 'pipeline builds'

      let(:pipeline) do
        create(:ci_pipeline,
               project: project,
               ref: 'master',
               sha: project.commit.id,
               user: user)
      end

      before do
        visit project_pipeline_path(project, pipeline)
      end

      it 'contains badge that indicates it is the latest build' do
        page.within(all('.well-segment')[1]) do
          expect(page).to have_content 'latest'
        end
      end
    end

    context 'when pipeline has configuration errors' do
      let(:pipeline) do
        create(:ci_pipeline,
               :invalid,
               project: project,
               ref: 'master',
               sha: project.commit.id,
               user: user)
      end

      before do
        visit project_pipeline_path(project, pipeline)
      end

      it 'contains badge that indicates errors' do
        page.within(all('.well-segment')[1]) do
          expect(page).to have_content 'yaml invalid'
        end
      end

      it 'contains badge with tooltip which contains error' do
        expect(pipeline).to have_yaml_errors

        page.within(all('.well-segment')[1]) do
          expect(page).to have_selector(
            %Q{span[title="#{pipeline.yaml_errors}"]})
        end
      end

      it 'contains badge that indicates failure reason' do
        expect(page).to have_content 'error'
      end

      it 'contains badge with tooltip which contains failure reason' do
        expect(pipeline.failure_reason?).to eq true

        page.within(all('.well-segment')[1]) do
          expect(page).to have_selector(
            %Q{span[title="#{pipeline.present.failure_reason}"]})
        end
      end

      it 'contains a pipeline header with title' do
        expect(page).to have_content "Pipeline ##{pipeline.id}"
      end
    end

    context 'when pipeline is stuck' do
      include_context 'pipeline builds'

      let(:pipeline) do
        create(:ci_pipeline,
               project: project,
               ref: 'master',
               sha: project.commit.id,
               user: user)
      end

      before do
        create(:ci_build, :pending, pipeline: pipeline)
        visit project_pipeline_path(project, pipeline)
      end

      it 'contains badge that indicates being stuck' do
        page.within(all('.well-segment')[1]) do
          expect(page).to have_content 'stuck'
        end
      end
    end

    context 'when pipeline uses auto devops' do
      include_context 'pipeline builds'

      let(:project) { create(:project, :repository, auto_devops_attributes: { enabled: true }) }
      let(:pipeline) do
        create(:ci_pipeline,
               :auto_devops_source,
               project: project,
               ref: 'master',
               sha: project.commit.id,
               user: user)
      end

      before do
        visit project_pipeline_path(project, pipeline)
      end

      it 'contains badge that indicates using auto devops' do
        page.within(all('.well-segment')[1]) do
          expect(page).to have_content 'Auto DevOps'
        end
      end
    end

    context 'when pipeline runs in a merge request context' do
      include_context 'pipeline builds'

      let(:pipeline) do
        create(:ci_pipeline,
               source: :merge_request_event,
               project: merge_request.source_project,
               ref: 'feature',
               sha: merge_request.diff_head_sha,
               user: user,
               merge_request: merge_request)
      end

      let(:merge_request) do
        create(:merge_request,
               source_project: project,
               source_branch: 'feature',
               target_project: project,
               target_branch: 'master')
      end

      before do
        visit project_pipeline_path(project, pipeline)
      end

      it 'contains badge that indicates detached merge request pipeline' do
        page.within(all('.well-segment')[1]) do
          expect(page).to have_content 'merge request'
        end
      end
    end
  end
end
