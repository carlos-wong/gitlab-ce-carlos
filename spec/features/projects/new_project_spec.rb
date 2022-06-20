# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'New project', :js do
  include Select2Helper
  include Spec::Support::Helpers::Features::TopNavSpecHelpers

  context 'as a user' do
    let(:user) { create(:user) }

    before do
      sign_in(user)
    end

    it 'shows a message if multiple levels are restricted' do
      Gitlab::CurrentSettings.update!(
        restricted_visibility_levels: [Gitlab::VisibilityLevel::PRIVATE, Gitlab::VisibilityLevel::INTERNAL]
      )

      visit new_project_path
      click_link 'Create blank project'

      expect(page).to have_content 'Other visibility settings have been disabled by the administrator.'
    end

    it 'shows a message if all levels are restricted' do
      Gitlab::CurrentSettings.update!(
        restricted_visibility_levels: Gitlab::VisibilityLevel.values
      )

      visit new_project_path
      click_link 'Create blank project'

      expect(page).to have_content 'Visibility settings have been disabled by the administrator.'
    end
  end

  context 'as an admin' do
    let(:user) { create(:admin) }

    before do
      sign_in(user)
    end

    it 'shows "New project" page', :js do
      visit new_project_path
      click_link 'Create blank project'

      expect(page).to have_content('Project name')
      expect(page).to have_content('Project URL')
      expect(page).to have_content('Project slug')

      click_link('New project')
      click_link 'Import project'

      expect(page).to have_link('GitHub')
      expect(page).to have_link('Bitbucket')
      expect(page).to have_link('GitLab.com')
      expect(page).to have_button('Repo by URL')
      expect(page).to have_link('GitLab export')
    end

    describe 'manifest import option' do
      before do
        visit new_project_path

        click_link 'Import project'
      end

      it 'has Manifest file' do
        expect(page).to have_link('Manifest file')
      end
    end

    context 'Visibility level selector', :js do
      Gitlab::VisibilityLevel.options.each do |key, level|
        it "sets selector to #{key}" do
          stub_application_setting(default_project_visibility: level)

          visit new_project_path
          click_link 'Create blank project'
          page.within('#blank-project-pane') do
            expect(find_field("project_visibility_level_#{level}")).to be_checked
          end
        end

        it "saves visibility level #{level} on validation error" do
          visit new_project_path
          click_link 'Create blank project'

          choose(key)
          click_button('Create project')
          page.within('#blank-project-pane') do
            expect(find_field("project_visibility_level_#{level}")).to be_checked
          end
        end
      end

      context 'when group visibility is private but default is internal' do
        let_it_be(:group) { create(:group, visibility_level: Gitlab::VisibilityLevel::PRIVATE) }

        before do
          stub_application_setting(default_project_visibility: Gitlab::VisibilityLevel::INTERNAL)
        end

        context 'when admin mode is enabled', :enable_admin_mode do
          it 'has private selected' do
            visit new_project_path(namespace_id: group.id)
            click_link 'Create blank project'

            page.within('#blank-project-pane') do
              expect(find_field("project_visibility_level_#{Gitlab::VisibilityLevel::PRIVATE}")).to be_checked
            end
          end
        end

        context 'when admin mode is disabled' do
          it 'is not allowed' do
            visit new_project_path(namespace_id: group.id)

            expect(page).to have_content('Not Found')
          end
        end
      end

      context 'when group visibility is public but user requests private' do
        let_it_be(:group) { create(:group, visibility_level: Gitlab::VisibilityLevel::PUBLIC) }

        before do
          stub_application_setting(default_project_visibility: Gitlab::VisibilityLevel::INTERNAL)
        end

        context 'when admin mode is enabled', :enable_admin_mode do
          it 'has private selected' do
            visit new_project_path(namespace_id: group.id, project: { visibility_level: Gitlab::VisibilityLevel::PRIVATE })
            click_link 'Create blank project'

            page.within('#blank-project-pane') do
              expect(find_field("project_visibility_level_#{Gitlab::VisibilityLevel::PRIVATE}")).to be_checked
            end
          end
        end

        context 'when admin mode is disabled' do
          it 'is not allowed' do
            visit new_project_path(namespace_id: group.id, project: { visibility_level: Gitlab::VisibilityLevel::PRIVATE })

            expect(page).to have_content('Not Found')
          end
        end
      end
    end

    context 'Readme selector' do
      it 'shows the initialize with Readme checkbox on "Blank project" tab' do
        visit new_project_path
        click_link 'Create blank project'

        expect(page).to have_css('input#project_initialize_with_readme')
        expect(page).to have_content('Initialize repository with a README')
      end

      it 'does not show the initialize with Readme checkbox on "Create from template" tab' do
        visit new_project_path
        click_link 'Create from template'
        first('.choose-template').click

        page.within '.project-fields-form' do
          expect(page).not_to have_css('input#project_initialize_with_readme')
          expect(page).not_to have_content('Initialize repository with a README')
        end
      end

      it 'does not show the initialize with Readme checkbox on "Import project" tab' do
        visit new_project_path
        click_link 'Import project'
        click_button 'Repo by URL'

        page.within '#import-project-pane' do
          expect(page).not_to have_css('input#project_initialize_with_readme')
          expect(page).not_to have_content('Initialize repository with a README')
        end
      end
    end

    context 'Namespace selector' do
      context 'with user namespace' do
        before do
          visit new_project_path
          click_link 'Create blank project'
        end

        it 'does not select the user namespace' do
          click_on 'Pick a group or namespace'
          expect(page).to have_button user.username
        end
      end

      context 'with group namespace' do
        let(:group) { create(:group, :private) }

        before do
          group.add_owner(user)
          visit new_project_path(namespace_id: group.id)
          click_link 'Create blank project'
        end

        it 'selects the group namespace' do
          expect(page).to have_button group.name
        end
      end

      context 'with subgroup namespace' do
        let(:group) { create(:group) }
        let(:subgroup) { create(:group, parent: group) }

        before do
          group.add_maintainer(user)
          visit new_project_path(namespace_id: subgroup.id)
          click_link 'Create blank project'
        end

        it 'selects the group namespace' do
          expect(page).to have_button subgroup.full_path
        end
      end

      context 'when changing namespaces dynamically', :js do
        let(:public_group) { create(:group, :public) }
        let(:internal_group) { create(:group, :internal) }
        let(:private_group) { create(:group, :private) }

        before do
          public_group.add_owner(user)
          internal_group.add_owner(user)
          private_group.add_owner(user)
          visit new_project_path(namespace_id: public_group.id)
          click_link 'Create blank project'
        end

        it 'enables the correct visibility options' do
          click_button public_group.full_path
          click_button user.username

          expect(find("#project_visibility_level_#{Gitlab::VisibilityLevel::PRIVATE}")).not_to be_disabled
          expect(find("#project_visibility_level_#{Gitlab::VisibilityLevel::INTERNAL}")).not_to be_disabled
          expect(find("#project_visibility_level_#{Gitlab::VisibilityLevel::PUBLIC}")).not_to be_disabled

          click_button user.username
          click_button public_group.full_path

          expect(find("#project_visibility_level_#{Gitlab::VisibilityLevel::PRIVATE}")).not_to be_disabled
          expect(find("#project_visibility_level_#{Gitlab::VisibilityLevel::INTERNAL}")).not_to be_disabled
          expect(find("#project_visibility_level_#{Gitlab::VisibilityLevel::PUBLIC}")).not_to be_disabled

          click_button public_group.full_path
          click_button internal_group.full_path

          expect(find("#project_visibility_level_#{Gitlab::VisibilityLevel::PRIVATE}")).not_to be_disabled
          expect(find("#project_visibility_level_#{Gitlab::VisibilityLevel::INTERNAL}")).not_to be_disabled
          expect(find("#project_visibility_level_#{Gitlab::VisibilityLevel::PUBLIC}")).to be_disabled

          click_button internal_group.full_path
          click_button private_group.full_path

          expect(find("#project_visibility_level_#{Gitlab::VisibilityLevel::PRIVATE}")).not_to be_disabled
          expect(find("#project_visibility_level_#{Gitlab::VisibilityLevel::INTERNAL}")).to be_disabled
          expect(find("#project_visibility_level_#{Gitlab::VisibilityLevel::PUBLIC}")).to be_disabled
        end
      end
    end

    context 'Import project options', :js do
      before do
        visit new_project_path
        click_link 'Import project'
      end

      context 'from git repository url, "Repo by URL"' do
        before do
          first('.js-import-git-toggle-button').click
        end

        it 'does not autocomplete sensitive git repo URL' do
          autocomplete = find('#project_import_url')['autocomplete']

          expect(autocomplete).to eq('off')
        end

        it 'shows import instructions' do
          git_import_instructions = first('.js-toggle-content')

          expect(git_import_instructions).to be_visible
          expect(git_import_instructions).to have_content 'Git repository URL'
        end

        it 'reports error if repo URL is not a valid Git repository' do
          stub_request(:get, "http://foo/bar/info/refs?service=git-upload-pack").to_return(status: 200, body: "not-a-git-repo")

          fill_in 'project_import_url', with: 'http://foo/bar'
          # simulate blur event
          find('body').click

          wait_for_requests

          expect(page).to have_text('There is not a valid Git repository at this URL')
        end

        it 'reports error if repo URL is not a valid Git repository and submit button is clicked immediately' do
          stub_request(:get, "http://foo/bar/info/refs?service=git-upload-pack").to_return(status: 200, body: "not-a-git-repo")

          fill_in 'project_import_url', with: 'http://foo/bar'
          click_on 'Create project'

          wait_for_requests

          expect(page).to have_text('There is not a valid Git repository at this URL')
        end

        it 'keeps "Import project" tab open after form validation error' do
          collision_project = create(:project, name: 'test-name-collision', namespace: user.namespace)
          stub_request(:get, "http://foo/bar/info/refs?service=git-upload-pack").to_return({ status: 200,
            body: '001e# service=git-upload-pack',
            headers: { 'Content-Type': 'application/x-git-upload-pack-advertisement' } })

          fill_in 'project_import_url', with: 'http://foo/bar'
          fill_in 'project_name', with: collision_project.name

          click_on 'Create project'

          expect(page).to have_content(
            s_('ProjectsNew|Pick a group or namespace where you want to create this project.')
          )

          click_on 'Pick a group or namespace'
          click_on user.username
          click_on 'Create project'

          expect(page).to have_css('#import-project-pane.active')
          expect(page).not_to have_css('.toggle-import-form.hide')
        end
      end

      context 'when import is initiated from project page' do
        before do
          project_without_repo = create(:project, name: 'project-without-repo', namespace: user.namespace)
          visit project_path(project_without_repo)
          click_on 'Import repository'
        end

        it 'reports error when invalid url is provided' do
          stub_request(:get, "http://foo/bar/info/refs?service=git-upload-pack").to_return(status: 200, body: "not-a-git-repo")

          fill_in 'project_import_url', with: 'http://foo/bar'

          click_on 'Start import'
          wait_for_requests

          expect(page).to have_text('There is not a valid Git repository at this URL')
        end

        it 'initiates import when valid repo url is provided' do
          stub_request(:get, "http://foo/bar/info/refs?service=git-upload-pack").to_return({ status: 200,
            body: '001e# service=git-upload-pack',
            headers: { 'Content-Type': 'application/x-git-upload-pack-advertisement' } })

          fill_in 'project_import_url', with: 'http://foo/bar'

          click_on 'Start import'
          wait_for_requests

          expect(page).to have_text('Import in progress')
        end
      end

      context 'from GitHub' do
        before do
          first('.js-import-github').click
        end

        it 'shows import instructions' do
          expect(page).to have_content('Authenticate with GitHub')
          expect(page).to have_current_path new_import_github_path, ignore_query: true
        end
      end

      context 'from manifest file' do
        before do
          first('.import_manifest').click
        end

        it 'shows import instructions' do
          expect(page).to have_content('Manifest file import')
          expect(page).to have_current_path new_import_manifest_path, ignore_query: true
        end
      end
    end

    context 'Namespace selector' do
      context 'with group with DEVELOPER_MAINTAINER_PROJECT_ACCESS project_creation_level' do
        let(:group) { create(:group, project_creation_level: ::Gitlab::Access::DEVELOPER_MAINTAINER_PROJECT_ACCESS) }

        before do
          group.add_developer(user)
          visit new_project_path(namespace_id: group.id)
          click_link 'Create blank project'
        end

        it 'selects the group namespace' do
          expect(page).to have_button group.full_path
        end
      end
    end
  end

  shared_examples 'has instructions to enable OAuth' do
    context 'when OAuth is not configured' do
      before do
        sign_in(user)

        allow(Gitlab::Auth::OAuth::Provider).to receive(:enabled?).and_call_original
        allow(Gitlab::Auth::OAuth::Provider)
          .to receive(:enabled?).with(provider)
          .and_return(false)

        visit new_project_path
        click_link 'Import project'
        click_link target_link
      end

      it 'shows import instructions' do
        expect(find('.modal-body')).to have_content(oauth_config_instructions)
      end
    end
  end

  context 'from Bitbucket', :js do
    let(:target_link) { 'Bitbucket Cloud' }
    let(:provider) { :bitbucket }

    context 'as a user' do
      let(:user) { create(:user) }
      let(:oauth_config_instructions) { 'To enable importing projects from Bitbucket, ask your GitLab administrator to configure OAuth integration' }

      it_behaves_like 'has instructions to enable OAuth'
    end

    context 'as an admin' do
      let(:user) { create(:admin) }
      let(:oauth_config_instructions) { 'To enable importing projects from Bitbucket, as administrator you need to configure OAuth integration' }

      it_behaves_like 'has instructions to enable OAuth'
    end
  end

  context 'from GitLab.com', :js do
    let(:target_link) { 'GitLab.com' }
    let(:provider) { :gitlab }

    context 'as a user' do
      let(:user) { create(:user) }
      let(:oauth_config_instructions) { 'To enable importing projects from GitLab.com, ask your GitLab administrator to configure OAuth integration' }

      it_behaves_like 'has instructions to enable OAuth'
    end

    context 'as an admin' do
      let(:user) { create(:admin) }
      let(:oauth_config_instructions) { 'To enable importing projects from GitLab.com, as administrator you need to configure OAuth integration' }

      it_behaves_like 'has instructions to enable OAuth'
    end
  end
end
