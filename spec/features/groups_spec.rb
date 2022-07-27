# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group' do
  let(:user) { create(:user) }

  before do
    sign_in(user)
  end

  matcher :have_namespace_error_message do
    match do |page|
      page.has_content?("Group URL can contain only letters, digits, '_', '-' and '.'. Cannot start with '-' or end in '.', '.git' or '.atom'.")
    end
  end

  describe 'create a group', :js do
    before do
      visit new_group_path
      click_link 'Create group'
    end

    describe 'as a non-admin' do
      it 'creates a group and persists visibility radio selection', :js do
        stub_application_setting(default_group_visibility: :private)

        fill_in 'Group name', with: 'test-group'
        find("input[name='group[visibility_level]'][value='#{Gitlab::VisibilityLevel::PUBLIC}']").click
        click_button 'Create group'

        group = Group.find_by(name: 'test-group')

        expect(group.visibility_level).to eq(Gitlab::VisibilityLevel::PUBLIC)
        expect(page).to have_current_path(group_path(group), ignore_query: true)
        expect(page).to have_selector '.visibility-icon [data-testid="earth-icon"]'
      end
    end

    describe 'with expected fields' do
      it 'renders from as expected', :aggregate_failures do
        expect(page).to have_field('name')
        expect(page).to have_field('group_path')
        expect(page).to have_field('group_visibility_level_0')
        expect(page).not_to have_field('description')
      end
    end

    describe 'with space in group path' do
      it 'renders new group form with validation errors' do
        fill_in 'Group URL', with: 'space group'
        click_button 'Create group'

        expect(page).to have_current_path(new_group_path, ignore_query: true)
        expect(page).to have_text('Choose a group path that does not start with a dash or end with a period. It can also contain alphanumeric characters and underscores.')
      end
    end

    describe 'with .atom at end of group path' do
      it 'renders new group form with validation errors' do
        fill_in 'Group name', with: 'test-group'
        fill_in 'Group URL', with: 'atom_group.atom'
        click_button 'Create group'

        expect(page).to have_current_path(groups_path, ignore_query: true)
        expect(page).to have_namespace_error_message
      end
    end

    describe 'with .git at end of group path' do
      it 'renders new group form with validation errors' do
        fill_in 'Group name', with: 'test-group'
        fill_in 'Group URL', with: 'git_group.git'
        click_button 'Create group'

        expect(page).to have_current_path(groups_path, ignore_query: true)
        expect(page).to have_namespace_error_message
      end
    end

    describe 'real-time group url validation', :js do
      it 'shows a message if group url is available' do
        fill_in 'group_path', with: 'az'
        wait_for_requests

        expect(page).to have_content('Group path is available')
      end

      it 'shows an error if group url is taken' do
        fill_in 'group_path', with: user.username
        wait_for_requests

        expect(page).to have_content("Group path is unavailable. Path has been replaced with a suggested available path.")
      end

      it 'does not break after an invalid form submit' do
        fill_in 'group_name', with: 'MyGroup'
        fill_in 'group_path', with: 'z'
        click_button 'Create group'

        expect(page).to have_content('Group URL is too short')

        fill_in 'group_path', with: 'az'
        wait_for_requests

        expect(page).to have_content('Group path is available')
      end

      context 'when filling in the `Group name` field' do
        let_it_be(:group1) { create(:group, :public, path: 'foo-bar') }
        let_it_be(:group2) { create(:group, :public, path: 'bar-baz') }

        it 'automatically populates the `Group URL` field' do
          fill_in 'Group name', with: 'Foo bar'
          # Wait for debounce in app/assets/javascripts/group.js#18
          sleep(1)
          fill_in 'Group name', with: 'Bar baz'
          # Wait for debounce in app/assets/javascripts/group.js#18
          sleep(1)

          wait_for_requests

          expect(page).to have_field('Group URL', with: 'bar-baz1')
        end
      end
    end

    describe 'Mattermost team creation' do
      before do
        stub_mattermost_setting(enabled: mattermost_enabled, host: 'https://mattermost.test')

        visit new_group_path
        click_link 'Create group'
      end

      context 'Mattermost enabled' do
        let(:mattermost_enabled) { true }

        it 'displays a team creation checkbox' do
          expect(page).to have_selector('#group_create_chat_team')
        end

        it 'unchecks the checkbox by default' do
          expect(find('#group_create_chat_team')).not_to be_checked
        end

        it 'updates the team URL on graph path update', :js do
          label = find('#group_create_chat_team ~ label[for=group_create_chat_team]')
          url = 'https://mattermost.test/test-group'

          expect(label.text).not_to match(url)

          fill_in('group_path', with: 'test-group')

          expect(label.text).to match(url)
        end
      end

      context 'Mattermost disabled' do
        let(:mattermost_enabled) { false }

        it 'doesnt show a team creation checkbox if Mattermost not enabled' do
          expect(page).not_to have_selector('#group_create_chat_team')
        end
      end
    end

    describe 'showing recaptcha on group creation when it is enabled' do
      before do
        stub_application_setting(recaptcha_enabled: true)
        allow(Gitlab::Recaptcha).to receive(:load_configurations!)
        visit new_group_path
        click_link 'Create group'
      end

      it 'renders recaptcha' do
        expect(page).to have_css('.recaptcha')
      end
    end

    describe 'not showing recaptcha on group creation when it is disabled' do
      before do
        stub_feature_flags(recaptcha_on_top_level_group_creation: false)
        stub_application_setting(recaptcha_enabled: true)
        visit new_group_path
        click_link 'Create group'
      end

      it 'does not render recaptcha' do
        expect(page).not_to have_css('.recaptcha')
      end
    end

    describe 'showing personalization questions on group creation when it is enabled' do
      before do
        stub_application_setting(hide_third_party_offers: false)
        visit new_group_path(anchor: 'create-group-pane')
      end

      it 'renders personalization questions' do
        expect(page).to have_content('Now, personalize your GitLab experience')
      end
    end

    describe 'not showing personalization questions on group creation when it is enabled' do
      before do
        stub_application_setting(hide_third_party_offers: true)
        visit new_group_path(anchor: 'create-group-pane')
      end

      it 'does not render personalization questions' do
        expect(page).not_to have_content('Now, personalize your GitLab experience')
      end
    end
  end

  describe 'create a nested group', :js do
    let_it_be(:group) { create(:group, path: 'foo') }

    context 'as admin' do
      let(:user) { create(:admin) }

      before do
        visit new_group_path(parent_id: group.id)
      end

      context 'when admin mode is enabled', :enable_admin_mode do
        it 'creates a nested group' do
          click_link 'Create group'
          fill_in 'Group name', with: 'bar'
          click_button 'Create group'

          expect(page).to have_current_path(group_path('foo/bar'), ignore_query: true)
          expect(page).to have_selector 'h1', text: 'bar'
        end
      end

      context 'when admin mode is disabled' do
        it 'is not allowed' do
          expect(page).not_to have_button('Create group')
        end
      end
    end

    context 'as group owner' do
      it 'creates a nested group' do
        user = create(:user)

        group.add_owner(user)
        sign_out(:user)
        sign_in(user)

        visit new_group_path(parent_id: group.id)
        click_link 'Create group'

        fill_in 'Group name', with: 'bar'
        click_button 'Create group'

        expect(page).to have_current_path(group_path('foo/bar'), ignore_query: true)
        expect(page).to have_selector 'h1', text: 'bar'
      end
    end

    context 'when recaptcha is enabled' do
      before do
        stub_application_setting(recaptcha_enabled: true)
        allow(Gitlab::Recaptcha).to receive(:load_configurations!)
      end

      context 'when creating subgroup' do
        let(:path) { new_group_path(parent_id: group.id) }

        it 'does not render recaptcha' do
          visit path

          expect(page).not_to have_css('.recaptcha')
        end
      end
    end

    describe 'real-time group url validation', :js do
      let_it_be(:subgroup) { create(:group, path: 'sub', parent: group) }

      before do
        group.add_owner(user)
        visit new_group_path(parent_id: group.id)
        click_link 'Create group'
      end

      it 'shows a message if group url is available' do
        fill_in 'Group URL', with: group.path
        wait_for_requests

        expect(page).to have_content('Group path is available')
      end

      it 'shows an error if group url is taken' do
        fill_in 'Group URL', with: subgroup.path
        wait_for_requests

        expect(page).to have_content("Group path is unavailable. Path has been replaced with a suggested available path.")
      end
    end
  end

  it 'checks permissions to avoid exposing groups by parent_id', :js do
    group = create(:group, :private, path: 'secret-group')

    sign_out(:user)
    sign_in(create(:user))
    visit new_group_path(parent_id: group.id)

    expect(page).to have_title('Not Found')
    expect(page).to have_content('Page Not Found')
  end

  describe 'group edit', :js do
    let_it_be(:group) { create(:group, :public) }

    let(:path) { edit_group_path(group) }
    let(:new_name) { 'new-name' }

    before do
      group.add_owner(user)

      visit path
    end

    it_behaves_like 'dirty submit form', [{ form: '.js-general-settings-form', input: 'input[name="group[name]"]' },
                                          { form: '.js-general-settings-form', input: '#group_visibility_level_0' },
                                          { form: '.js-general-permissions-form', input: '#group_request_access_enabled' },
                                          { form: '.js-general-permissions-form', input: 'input[name="group[two_factor_grace_period]"]' }]

    it 'saves new settings' do
      page.within('.gs-general') do
        # Have to reset it to '' so it overwrites rather than appends
        fill_in('group_name', with: '')
        fill_in 'group_name', with: new_name
        click_button 'Save changes'
      end

      expect(page).to have_content 'successfully updated'
      expect(find('#group_name').value).to eq(new_name)

      page.within ".breadcrumbs" do
        expect(page).to have_content new_name
      end
    end

    it 'focuses confirmation field on remove group' do
      click_button('Remove group')

      expect(page).to have_selector '#confirm_name_input:focus'
    end

    it 'removes group', :sidekiq_might_not_need_inline do
      expect { remove_with_confirm('Remove group', group.path) }.to change {Group.count}.by(-1)
      expect(group.members.all.count).to be_zero
      expect(page).to have_content "scheduled for deletion"
    end
  end

  describe 'group page with markdown description' do
    let_it_be(:group) { create(:group) }

    let(:path) { group_path(group) }

    before do
      group.add_owner(user)
    end

    it 'parses Markdown' do
      group.update_attribute(:description, 'This is **my** group')

      visit path

      expect(page).to have_css('.home-panel-description-markdown > p > strong')
    end

    it 'passes through html-pipeline' do
      group.update_attribute(:description, 'This group is the :poop:')

      visit path

      expect(page).to have_css('.home-panel-description-markdown > p > gl-emoji')
    end

    it 'sanitizes unwanted tags' do
      group.update_attribute(:description, '# Group Description')

      visit path

      expect(page).not_to have_css('.home-panel-description-markdown h1')
    end

    it 'permits `rel` attribute on links' do
      group.update_attribute(:description, 'https://google.com/')

      visit path

      expect(page).to have_css('.home-panel-description-markdown a[rel]')
    end
  end

  describe 'group page with nested groups', :js do
    let_it_be(:group) { create(:group) }
    let_it_be(:nested_group) { create(:group, parent: group) }
    let_it_be(:project) { create(:project, namespace: group) }

    before do
      group.add_owner(user)
    end

    it 'renders projects and groups on the page' do
      visit group_path(group)
      wait_for_requests

      expect(page).to have_content(nested_group.name)
      expect(page).to have_content(project.name)
      expect(page).to have_link('Group information')
    end

    it 'renders subgroup page with the text "Subgroup information"' do
      visit group_path(nested_group)
      wait_for_requests

      expect(page).to have_link('Subgroup information')
    end

    it 'renders project page with the text "Project information"' do
      visit project_path(project)
      wait_for_requests

      expect(page).to have_link('Project information')
    end
  end

  describe 'new subgroup / project button' do
    let_it_be(:group, reload: true) do
      create(:group,
             project_creation_level: Gitlab::Access::NO_ONE_PROJECT_ACCESS,
             subgroup_creation_level: Gitlab::Access::OWNER_SUBGROUP_ACCESS)
    end

    before do
      group.add_owner(user)
    end

    context 'when user has subgroup creation permissions but not project creation permissions' do
      it 'only displays "New subgroup" button' do
        visit group_path(group)

        page.within '[data-testid="group-buttons"]' do
          expect(page).to have_link('New subgroup')
          expect(page).not_to have_link('New project')
        end
      end
    end

    context 'when user has project creation permissions but not subgroup creation permissions' do
      it 'only displays "New project" button' do
        group.update!(project_creation_level: Gitlab::Access::MAINTAINER_PROJECT_ACCESS)
        user = create(:user)

        group.add_maintainer(user)
        sign_out(:user)
        sign_in(user)

        visit group_path(group)
        page.within '[data-testid="group-buttons"]' do
          expect(page).to have_link('New project')
          expect(page).not_to have_link('New subgroup')
        end
      end
    end

    context 'when user has project and subgroup creation permissions' do
      it 'displays "New subgroup" and "New project" buttons' do
        group.update!(project_creation_level: Gitlab::Access::MAINTAINER_PROJECT_ACCESS)

        visit group_path(group)

        page.within '[data-testid="group-buttons"]' do
          expect(page).to have_link('New subgroup')
          expect(page).to have_link('New project')
        end
      end
    end
  end

  def remove_with_confirm(button_text, confirm_with)
    click_button button_text
    fill_in 'confirm_name_input', with: confirm_with
    click_button 'Confirm'
  end

  describe 'storage_enforcement_banner', :js do
    let_it_be(:group) { create(:group) }
    let_it_be_with_refind(:user) { create(:user) }

    before do
      group.add_owner(user)
      sign_in(user)
    end

    context 'with storage_enforcement_date set' do
      let_it_be(:storage_enforcement_date) { Date.today + 30 }

      before do
        allow_next_found_instance_of(Group) do |grp|
          allow(grp).to receive(:storage_enforcement_date).and_return(storage_enforcement_date)
        end
      end

      it 'displays the banner in the group page' do
        visit group_path(group)
        expect_page_to_have_storage_enforcement_banner(storage_enforcement_date)
      end

      it 'does not display the banner in a paid group page' do
        allow_next_found_instance_of(Group) do |grp|
          allow(grp).to receive(:paid?).and_return(true)
        end
        visit group_path(group)
        expect_page_not_to_have_storage_enforcement_banner
      end

      it 'does not display the banner if user has previously closed unless threshold has changed' do
        visit group_path(group)
        expect_page_to_have_storage_enforcement_banner(storage_enforcement_date)
        find('.js-storage-enforcement-banner [data-testid="close-icon"]').click
        wait_for_requests
        page.refresh
        expect_page_not_to_have_storage_enforcement_banner

        storage_enforcement_date = Date.today + 13
        allow_next_found_instance_of(Group) do |grp|
          allow(grp).to receive(:storage_enforcement_date).and_return(storage_enforcement_date)
        end
        page.refresh
        expect_page_to_have_storage_enforcement_banner(storage_enforcement_date)
      end
    end

    context 'with storage_enforcement_date not set' do
      # This test should break and be rewritten after the implementation of the storage_enforcement_date
      # TBD: https://gitlab.com/gitlab-org/gitlab/-/issues/350632
      it 'does not display the banner in the group page' do
        stub_feature_flags(namespace_storage_limit_bypass_date_check: false)
        visit group_path(group)
        expect_page_not_to_have_storage_enforcement_banner
      end
    end
  end

  def expect_page_to_have_storage_enforcement_banner(storage_enforcement_date)
    expect(page).to have_text "From #{storage_enforcement_date} storage limits will apply to this namespace"
  end

  def expect_page_not_to_have_storage_enforcement_banner
    expect(page).not_to have_text "storage limits will apply to this namespace"
  end
end
