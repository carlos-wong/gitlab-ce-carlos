# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "Admin Runners" do
  include Spec::Support::Helpers::Features::RunnersHelpers
  include Spec::Support::Helpers::ModalHelpers

  let_it_be(:admin) { create(:admin) }

  before do
    sign_in(admin)
    gitlab_enable_admin_mode_sign_in(admin)

    wait_for_requests
  end

  describe "Admin Runners page", :js do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:namespace) { create(:namespace) }
    let_it_be(:project) { create(:project, namespace: namespace, creator: user) }

    describe "runners registration" do
      before do
        visit admin_runners_path
      end

      it_behaves_like "shows and resets runner registration token" do
        let(:dropdown_text) { 'Register an instance runner' }
        let(:registration_token) { Gitlab::CurrentSettings.runners_registration_token }
      end
    end

    context "when there are runners" do
      context "with an instance runner" do
        let!(:instance_runner) { create(:ci_runner, :instance) }

        before do
          visit admin_runners_path
        end

        it_behaves_like 'shows runner in list' do
          let(:runner) { instance_runner }
        end

        it_behaves_like 'pauses, resumes and deletes a runner' do
          let(:runner) { instance_runner }
        end

        it 'shows an instance badge' do
          within_runner_row(instance_runner.id) do
            expect(page).to have_selector '.badge', text: 'shared'
          end
        end
      end

      context "with multiple runners" do
        before do
          create(:ci_runner, :instance, created_at: 1.year.ago, contacted_at: Time.zone.now)
          create(:ci_runner, :instance, created_at: 1.year.ago, contacted_at: 1.week.ago)
          create(:ci_runner, :instance, created_at: 1.year.ago, contacted_at: 1.year.ago)

          visit admin_runners_path
        end

        it 'has all necessary texts' do
          expect(page).to have_text "Register an instance runner"
          expect(page).to have_text "Online runners 1"
          expect(page).to have_text "Offline runners 2"
          expect(page).to have_text "Stale runners 1"
        end
      end

      it 'shows a job count' do
        runner = create(:ci_runner, :project, projects: [project])

        create(:ci_build, runner: runner)
        create(:ci_build, runner: runner)

        visit admin_runners_path

        within_runner_row(runner.id) do
          expect(find("[data-label='Jobs']")).to have_content '2'
        end
      end

      describe 'search' do
        before do
          create(:ci_runner, :instance, description: 'runner-foo')
          create(:ci_runner, :instance, description: 'runner-bar')

          visit admin_runners_path
        end

        it 'runner types tabs have total counts and can be selected' do
          expect(page).to have_link('All 2')
          expect(page).to have_link('Instance 2')
          expect(page).to have_link('Group 0')
          expect(page).to have_link('Project 0')
        end

        it 'shows runners' do
          expect(page).to have_content("runner-foo")
          expect(page).to have_content("runner-bar")
        end

        it 'shows correct runner when description matches' do
          input_filtered_search_keys('runner-foo')

          expect(page).to have_link('All 1')
          expect(page).to have_link('Instance 1')

          expect(page).to have_content("runner-foo")
          expect(page).not_to have_content("runner-bar")
        end

        context 'when description does not match' do
          before do
            input_filtered_search_keys('runner-baz')
          end

          it_behaves_like 'shows no runners found'

          it 'shows no runner' do
            expect(page).to have_link('All 0')
            expect(page).to have_link('Instance 0')
          end
        end
      end

      describe 'filter by paused' do
        before do
          create(:ci_runner, :instance, description: 'runner-active')
          create(:ci_runner, :instance, description: 'runner-paused', active: false)

          visit admin_runners_path
        end

        it 'shows all runners' do
          expect(page).to have_link('All 2')

          expect(page).to have_content 'runner-active'
          expect(page).to have_content 'runner-paused'
        end

        it 'shows paused runners' do
          input_filtered_search_filter_is_only('Paused', 'Yes')

          expect(page).to have_link('All 1')

          expect(page).not_to have_content 'runner-active'
          expect(page).to have_content 'runner-paused'
        end

        it 'shows active runners' do
          input_filtered_search_filter_is_only('Paused', 'No')

          expect(page).to have_link('All 1')

          expect(page).to have_content 'runner-active'
          expect(page).not_to have_content 'runner-paused'
        end
      end

      describe 'filter by status' do
        let!(:never_contacted) do
          create(:ci_runner, :instance, description: 'runner-never-contacted', contacted_at: nil)
        end

        before do
          create(:ci_runner, :instance, description: 'runner-1', contacted_at: Time.zone.now)
          create(:ci_runner, :instance, description: 'runner-2', contacted_at: Time.zone.now)
          create(:ci_runner, :instance, description: 'runner-offline', contacted_at: 1.week.ago)

          visit admin_runners_path
        end

        it 'shows all runners' do
          expect(page).to have_link('All 4')

          expect(page).to have_content 'runner-1'
          expect(page).to have_content 'runner-2'
          expect(page).to have_content 'runner-offline'
          expect(page).to have_content 'runner-never-contacted'
        end

        it 'shows correct runner when status matches' do
          input_filtered_search_filter_is_only('Status', 'Online')

          expect(page).to have_link('All 2')

          expect(page).to have_content 'runner-1'
          expect(page).to have_content 'runner-2'
          expect(page).not_to have_content 'runner-offline'
          expect(page).not_to have_content 'runner-never-contacted'
        end

        it 'shows correct runner when status is selected and search term is entered' do
          input_filtered_search_filter_is_only('Status', 'Online')
          input_filtered_search_keys('runner-1')

          expect(page).to have_link('All 1')

          expect(page).to have_content 'runner-1'
          expect(page).not_to have_content 'runner-2'
          expect(page).not_to have_content 'runner-offline'
          expect(page).not_to have_content 'runner-never-contacted'
        end

        it 'shows correct runner when status filter is entered' do
          # use the string "Never" to avoid using space and trigger an early selection
          input_filtered_search_filter_is_only('Status', 'Never')

          expect(page).to have_link('All 1')

          expect(page).not_to have_content 'runner-1'
          expect(page).not_to have_content 'runner-2'
          expect(page).not_to have_content 'runner-paused'
          expect(page).to have_content 'runner-never-contacted'

          within_runner_row(never_contacted.id) do
            expect(page).to have_selector '.badge', text: 'never contacted'
          end
        end

        context 'when status does not match' do
          before do
            input_filtered_search_filter_is_only('Status', 'Stale')
          end

          it_behaves_like 'shows no runners found'

          it 'shows no runner' do
            expect(page).to have_link('All 0')
          end
        end
      end

      describe 'filter by type' do
        before do
          create(:ci_runner, :project, description: 'runner-project', projects: [project])
          create(:ci_runner, :group, description: 'runner-group', groups: [group])
        end

        it '"All" tab is selected by default' do
          visit admin_runners_path

          expect(page).to have_link('All 2')
          expect(page).to have_link('Group 1')
          expect(page).to have_link('Project 1')

          page.within('[data-testid="runner-type-tabs"]') do
            expect(page).to have_link('All', class: 'active')
          end
        end

        it 'shows correct runner when type matches' do
          visit admin_runners_path

          expect(page).to have_content 'runner-project'
          expect(page).to have_content 'runner-group'

          page.within('[data-testid="runner-type-tabs"]') do
            click_on('Project')

            expect(page).to have_link('Project', class: 'active')
          end

          expect(page).to have_content 'runner-project'
          expect(page).not_to have_content 'runner-group'
        end

        it 'show the same counts after selecting another tab' do
          visit admin_runners_path

          page.within('[data-testid="runner-type-tabs"]') do
            click_on('Project')

            expect(page).to have_link('All 2')
            expect(page).to have_link('Group 1')
            expect(page).to have_link('Project 1')
          end
        end

        it 'shows correct runner when type is selected and search term is entered' do
          create(:ci_runner, :project, description: 'runner-2-project', projects: [project])

          visit admin_runners_path

          page.within('[data-testid="runner-type-tabs"]') do
            click_on 'Project'
          end

          expect(page).to have_content 'runner-project'
          expect(page).to have_content 'runner-2-project'
          expect(page).not_to have_content 'runner-group'

          input_filtered_search_keys('runner-project')

          expect(page).to have_content 'runner-project'
          expect(page).not_to have_content 'runner-2-project'
          expect(page).not_to have_content 'runner-group'
        end

        it 'maintains the same filter when switching between runner types' do
          create(:ci_runner, :project, description: 'runner-paused-project', active: false, projects: [project])

          visit admin_runners_path

          input_filtered_search_filter_is_only('Paused', 'No')

          expect(page).to have_content 'runner-project'
          expect(page).to have_content 'runner-group'
          expect(page).not_to have_content 'runner-paused-project'

          page.within('[data-testid="runner-type-tabs"]') do
            click_on 'Project'
          end

          expect(page).to have_content 'runner-project'
          expect(page).not_to have_content 'runner-group'
          expect(page).not_to have_content 'runner-paused-project'
        end

        context 'when type does not match' do
          before do
            visit admin_runners_path
            page.within('[data-testid="runner-type-tabs"]') do
              click_on 'Instance'
            end
          end

          it_behaves_like 'shows no runners found'

          it 'shows active tab' do
            expect(page).to have_link('Instance', class: 'active')
          end

          it 'shows no runner' do
            expect(page).not_to have_content 'runner-project'
            expect(page).not_to have_content 'runner-group'
          end
        end
      end

      describe 'filter by tag' do
        before do
          create(:ci_runner, :instance, description: 'runner-blue', tag_list: ['blue'])
          create(:ci_runner, :instance, description: 'runner-red', tag_list: ['red'])
        end

        it 'shows tags suggestions' do
          visit admin_runners_path

          open_filtered_search_suggestions('Tags')

          page.within(search_bar_selector) do
            expect(page).to have_content 'blue'
            expect(page).to have_content 'red'
          end
        end

        it 'shows correct runner when tag matches' do
          visit admin_runners_path

          expect(page).to have_content 'runner-blue'
          expect(page).to have_content 'runner-red'

          input_filtered_search_filter_is_only('Tags', 'blue')

          expect(page).to have_content 'runner-blue'
          expect(page).not_to have_content 'runner-red'
        end

        it 'shows correct runner when tag is selected and search term is entered' do
          create(:ci_runner, :instance, description: 'runner-2-blue', tag_list: ['blue'])

          visit admin_runners_path

          input_filtered_search_filter_is_only('Tags', 'blue')

          expect(page).to have_content 'runner-blue'
          expect(page).to have_content 'runner-2-blue'
          expect(page).not_to have_content 'runner-red'

          input_filtered_search_keys('runner-2-blue')

          expect(page).to have_content 'runner-2-blue'
          expect(page).not_to have_content 'runner-blue'
          expect(page).not_to have_content 'runner-red'
        end

        context 'when tag does not match' do
          before do
            visit admin_runners_path
            input_filtered_search_filter_is_only('Tags', 'green')
          end

          it_behaves_like 'shows no runners found'

          it 'shows no runner' do
            expect(page).not_to have_content 'runner-blue'
          end
        end
      end

      it 'sorts by last contact date' do
        create(:ci_runner, :instance, description: 'runner-1', contacted_at: '2018-07-12')
        create(:ci_runner, :instance, description: 'runner-2', contacted_at: '2018-07-13')

        visit admin_runners_path

        within '[data-testid="runner-list"] tbody tr:nth-child(1)' do
          expect(page).to have_content 'runner-2'
        end

        within '[data-testid="runner-list"] tbody tr:nth-child(2)' do
          expect(page).to have_content 'runner-1'
        end

        click_on 'Created date' # Open "sort by" dropdown
        click_on 'Last contact'
        click_on 'Sort direction: Descending'

        within '[data-testid="runner-list"] tbody tr:nth-child(1)' do
          expect(page).to have_content 'runner-1'
        end

        within '[data-testid="runner-list"] tbody tr:nth-child(2)' do
          expect(page).to have_content 'runner-2'
        end
      end
    end

    context "when there are no runners" do
      before do
        visit admin_runners_path
      end

      it_behaves_like 'shows no runners registered'

      it 'shows tabs with total counts equal to 0' do
        expect(page).to have_link('All 0')
        expect(page).to have_link('Instance 0')
        expect(page).to have_link('Group 0')
        expect(page).to have_link('Project 0')
      end
    end

    context "when visiting outdated URLs" do
      it 'updates ACTIVE runner status to paused=false' do
        visit admin_runners_path('status[]': 'ACTIVE')

        expect(page).to have_current_path(admin_runners_path('paused[]': 'false'))
      end

      it 'updates PAUSED runner status to paused=true' do
        visit admin_runners_path('status[]': 'PAUSED')

        expect(page).to have_current_path(admin_runners_path('paused[]': 'true'))
      end
    end
  end

  describe "Runner show page", :js do
    let(:runner) do
      create(
        :ci_runner,
        description: 'runner-foo',
        version: '14.0',
        ip_address: '127.0.0.1',
        tag_list: ['tag1']
      )
    end

    before do
      visit admin_runner_path(runner)
    end

    describe 'runner show page breadcrumbs' do
      it 'contains the current runner id and token' do
        page.within '[data-testid="breadcrumb-links"]' do
          expect(page.find('[data-testid="breadcrumb-current-link"]')).to have_link(
            "##{runner.id} (#{runner.short_sha})"
          )
        end
      end
    end

    it 'shows runner details' do
      aggregate_failures do
        expect(page).to have_content 'Description runner-foo'
        expect(page).to have_content 'Last contact Never contacted'
        expect(page).to have_content 'Version 14.0'
        expect(page).to have_content 'IP Address 127.0.0.1'
        expect(page).to have_content 'Configuration Runs untagged jobs'
        expect(page).to have_content 'Maximum job timeout None'
        expect(page).to have_content 'Tags tag1'
      end
    end

    describe 'when a runner is deleted' do
      before do
        click_on 'Delete runner'

        within_modal do
          click_on 'Delete runner'
        end
      end

      it 'deletes runner' do
        expect(page.find('[data-testid="alert-success"]')).to have_content('deleted')
      end

      it 'redirects to runner list' do
        expect(current_url).to match(admin_runners_path)
      end
    end
  end

  describe "Runner edit page" do
    let(:runner) { create(:ci_runner, :project) }
    let!(:project1) { create(:project) }
    let!(:project2) { create(:project) }

    before do
      visit edit_admin_runner_path(runner)

      wait_for_requests
    end

    describe 'breadcrumbs' do
      it 'contains the current runner id and token' do
        page.within '[data-testid="breadcrumb-links"]' do
          expect(page).to have_link("##{runner.id} (#{runner.short_sha})")
          expect(page.find('[data-testid="breadcrumb-current-link"]')).to have_content("Edit")
        end
      end
    end

    describe 'runner header', :js do
      it 'contains the runner status, type and id' do
        expect(page).to have_content("never contacted specific Runner ##{runner.id} created")
      end
    end

    context 'when a runner is updated', :js do
      before do
        click_on _('Save changes')
        wait_for_requests
      end

      it 'show success alert' do
        expect(page.find('[data-testid="alert-success"]')).to have_content('saved')
      end

      it 'redirects to runner page' do
        expect(current_url).to match(admin_runner_path(runner))
      end
    end

    describe 'projects' do
      it 'contains project names' do
        expect(page).to have_content(project1.full_name)
        expect(page).to have_content(project2.full_name)
      end
    end

    describe 'search' do
      before do
        search_form = find('#runner-projects-search')
        search_form.fill_in 'search', with: project1.name
        search_form.click_button 'Search'
      end

      it 'contains name of correct project' do
        expect(page).to have_content(project1.full_name)
        expect(page).not_to have_content(project2.full_name)
      end
    end

    describe 'enable/create' do
      shared_examples 'assignable runner' do
        it 'enables a runner for a project' do
          within '[data-testid="unassigned-projects"]' do
            click_on 'Enable'
          end

          assigned_project = page.find('[data-testid="assigned-projects"]')

          expect(page).to have_content('Runner assigned to project.')
          expect(assigned_project).to have_content(project2.path)
        end
      end

      context 'with specific runner' do
        let(:runner) { create(:ci_runner, :project, projects: [project1]) }

        before do
          visit edit_admin_runner_path(runner)
        end

        it_behaves_like 'assignable runner'
      end

      context 'with locked runner' do
        let(:runner) { create(:ci_runner, :project, projects: [project1], locked: true) }

        before do
          visit edit_admin_runner_path(runner)
        end

        it_behaves_like 'assignable runner'
      end
    end

    describe 'disable/destroy' do
      let(:runner) { create(:ci_runner, :project, projects: [project1]) }

      before do
        visit edit_admin_runner_path(runner)
      end

      it 'removed specific runner from project' do
        within '[data-testid="assigned-projects"]' do
          click_on 'Disable'
        end

        new_runner_project = page.find('[data-testid="unassigned-projects"]')

        expect(page).to have_content('Runner unassigned from project.')
        expect(new_runner_project).to have_content(project1.path)
      end
    end
  end
end
