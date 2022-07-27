# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "Admin::Projects" do
  include Spec::Support::Helpers::Features::MembersHelpers
  include Spec::Support::Helpers::Features::InviteMembersModalHelper
  include Spec::Support::Helpers::ModalHelpers

  let_it_be_with_reload(:user) { create :user }
  let_it_be_with_reload(:project) { create(:project, :with_namespace_settings) }
  let_it_be_with_reload(:current_user) { create(:admin) }

  before do
    sign_in(current_user)
    gitlab_enable_admin_mode_sign_in(current_user)
  end

  describe 'when membership is set to expire', :js do
    it 'renders relative time' do
      expire_time = Time.current + 2.days
      current_user.update!(time_display_relative: true)
      project.add_member(user, Gitlab::Access::REPORTER, expires_at: expire_time)

      visit admin_project_path(project)

      expect(page).to have_content(/Expires in \d day/)
    end

    it 'renders absolute time' do
      expire_time = Time.current.tomorrow.middle_of_day
      current_user.update!(time_display_relative: false)
      project.add_member(user, Gitlab::Access::REPORTER, expires_at: expire_time)

      visit admin_project_path(project)

      expect(page).to have_content("Expires on #{expire_time.strftime('%b %-d')}")
    end
  end

  describe "GET /admin/projects" do
    let!(:archived_project) { create :project, :public, :archived }

    before do
      expect(project).to be_persisted
      visit admin_projects_path
    end

    it "is ok" do
      expect(page).to have_current_path(admin_projects_path, ignore_query: true)
    end

    it 'renders projects list without archived project' do
      expect(page).to have_content(project.name)
      expect(page).not_to have_content(archived_project.name)
    end

    it 'renders all projects', :js do
      find(:css, '#sort-projects-dropdown').click
      click_link 'Show archived projects'

      expect(page).to have_content(project.name)
      expect(page).to have_content(archived_project.name)
      expect(page).to have_xpath("//span[@class='gl-badge badge badge-pill badge-warning md']", text: 'archived')
    end

    it 'renders only archived projects', :js do
      find(:css, '#sort-projects-dropdown').click
      click_link 'Show archived projects only'

      expect(page).to have_content(archived_project.name)
      expect(page).not_to have_content(project.name)
    end
  end

  describe "GET /admin/projects/:namespace_id/:id" do
    let!(:access_request) { create(:project_member, :access_request, project: project) }

    before do
      expect(project).to be_persisted

      visit admin_projects_path
      click_link project.name
    end

    it "has project info" do
      expect(page).to have_current_path admin_project_path(project), ignore_query: true
      expect(page).to have_content(project.path)
      expect(page).to have_content(project.name)
      expect(page).to have_content(project.full_name)
      expect(page).to have_content(project.creator.name)
      expect(page).to have_content(project.id)
    end

    context 'when project has open access requests' do
      it 'shows access requests with link to manage access' do
        page.within '[data-testid="access-requests"]' do
          expect(page).to have_content access_request.user.name
          expect(page).to have_link 'Manage access', href: project_project_members_path(project, tab: 'access_requests')
        end
      end
    end
  end

  describe 'transfer project' do
    # The gitlab-shell transfer will fail for a project without a repository
    let(:project) { create(:project, :repository, :with_namespace_settings) }

    before do
      create(:group, name: 'Web')

      allow_next_instance_of(Projects::TransferService) do |instance|
        allow(instance).to receive(:move_uploads_to_new_namespace).and_return(true)
      end
    end

    it 'transfers project to group web', :js do
      visit admin_project_path(project)

      click_button 'Search for Namespace'
      click_button 'group: web'
      click_button 'Transfer'

      expect(page).to have_content("Web / #{project.name}")
      expect(page).to have_content('Namespace: Web')
    end
  end

  describe 'admin adds themselves to the project', :js do
    before do
      project.add_maintainer(user)
    end

    it 'adds admin to the project as developer' do
      visit project_project_members_path(project)

      invite_member(current_user.name, role: 'Developer')

      expect(find_member_row(current_user)).to have_content('Developer')
    end
  end

  describe 'admin removes themselves from the project', :js do
    before do
      project.add_maintainer(user)
      project.add_developer(current_user)
    end

    it 'removes admin from the project' do
      visit project_project_members_path(project)

      expect(find_member_row(current_user)).to have_content('Developer')

      page.within find_member_row(current_user) do
        click_button 'Leave'
      end

      within_modal do
        click_button('Leave')
      end

      expect(page).to have_current_path(dashboard_projects_path, ignore_query: true, url: false)
    end
  end
end
