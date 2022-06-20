# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "Group Runners" do
  include Spec::Support::Helpers::Features::RunnersHelpers

  let_it_be(:group_owner) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  before do
    group.add_owner(group_owner)
    sign_in(group_owner)
  end

  describe "Group runners page", :js do
    let!(:group_registration_token) { group.runners_token }

    context "runners registration" do
      before do
        visit group_runners_path(group)
      end

      it_behaves_like "shows and resets runner registration token" do
        let(:dropdown_text) { 'Register a group runner' }
        let(:registration_token) { group_registration_token }
      end
    end

    context "with no runners" do
      before do
        visit group_runners_path(group)
      end

      it_behaves_like "shows no runners"

      it 'shows tabs with total counts equal to 0' do
        expect(page).to have_link('All 0')
        expect(page).to have_link('Group 0')
        expect(page).to have_link('Project 0')
      end
    end

    context "with an online group runner" do
      let!(:group_runner) do
        create(:ci_runner, :group, groups: [group], description: 'runner-foo', contacted_at: Time.zone.now)
      end

      before do
        visit group_runners_path(group)
      end

      it_behaves_like 'shows runner in list' do
        let(:runner) { group_runner }
      end

      it_behaves_like 'pauses, resumes and deletes a runner' do
        let(:runner) { group_runner }
      end

      it 'shows a group badge' do
        within_runner_row(group_runner.id) do
          expect(page).to have_selector '.badge', text: 'group'
        end
      end

      it 'can edit runner information' do
        within_runner_row(group_runner.id) do
          expect(find_link('Edit')[:href]).to end_with(edit_group_runner_path(group, group_runner))
        end
      end
    end

    context "with an online project runner" do
      let!(:project_runner) do
        create(:ci_runner, :project, projects: [project], description: 'runner-bar', contacted_at: Time.zone.now)
      end

      before do
        visit group_runners_path(group)
      end

      it_behaves_like 'shows runner in list' do
        let(:runner) { project_runner }
      end

      it_behaves_like 'pauses, resumes and deletes a runner' do
        let(:runner) { project_runner }
      end

      it 'shows a project (specific) badge' do
        within_runner_row(project_runner.id) do
          expect(page).to have_selector '.badge', text: 'specific'
        end
      end

      it 'can edit runner information' do
        within_runner_row(project_runner.id) do
          expect(find_link('Edit')[:href]).to end_with(edit_group_runner_path(group, project_runner))
        end
      end
    end

    context 'with a multi-project runner' do
      let(:project) { create(:project, group: group) }
      let(:project_2) { create(:project, group: group) }
      let!(:runner) { create(:ci_runner, :project, projects: [project, project_2], description: 'group-runner') }

      it 'user cannot remove the project runner' do
        visit group_runners_path(group)

        within_runner_row(runner.id) do
          expect(page).to have_button 'Delete runner', disabled: true
        end
      end
    end

    context 'filtered search' do
      before do
        visit group_runners_path(group)
      end

      it 'allows user to search by paused and status', :js do
        focus_filtered_search

        page.within(search_bar_selector) do
          expect(page).to have_link('Paused')
          expect(page).to have_content('Status')
        end
      end
    end
  end

  describe "Group runner edit page", :js do
    let!(:runner) do
      create(:ci_runner, :group, groups: [group], description: 'runner-foo', contacted_at: Time.zone.now)
    end

    it 'user edits the runner to be protected' do
      visit edit_group_runner_path(group, runner)

      expect(page.find_field('runner[access_level]')).not_to be_checked

      check 'runner_access_level'
      click_button 'Save changes'

      expect(page).to have_content 'Protected Yes'
    end

    context 'when a runner has a tag' do
      before do
        runner.update!(tag_list: ['tag'])
      end

      it 'user edits runner not to run untagged jobs' do
        visit edit_group_runner_path(group, runner)

        expect(page.find_field('runner[run_untagged]')).to be_checked

        uncheck 'runner_run_untagged'
        click_button 'Save changes'

        expect(page).to have_content 'Can run untagged jobs No'
      end
    end
  end
end
