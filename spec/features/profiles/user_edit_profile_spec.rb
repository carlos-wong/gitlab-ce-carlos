# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User edit profile' do
  include Spec::Support::Helpers::Features::NotesHelpers

  let(:user) { create(:user) }

  before do
    sign_in(user)
    visit(profile_path)
  end

  def submit_settings
    click_button 'Update profile settings'
    wait_for_requests if respond_to?(:wait_for_requests)
  end

  def update_user_email
    fill_in 'user_email', with: 'new-email@example.com'
    click_button 'Update profile settings'
  end

  def confirm_password(password)
    fill_in 'password-confirmation', with: password
    click_button 'Confirm password'
    wait_for_requests if respond_to?(:wait_for_requests)
  end

  def visit_user
    visit user_path(user)
    wait_for_requests
  end

  def toggle_busy_status
    find('[data-testid="user-availability-checkbox"]').set(true)
  end

  it 'changes user profile' do
    fill_in 'user_skype', with: 'testskype'
    fill_in 'user_linkedin', with: 'testlinkedin'
    fill_in 'user_twitter', with: 'testtwitter'
    fill_in 'user_website_url', with: 'http://testurl.com'
    fill_in 'user_location', with: 'Ukraine'
    fill_in 'user_bio', with: 'I <3 GitLab :tada:'
    fill_in 'user_job_title', with: 'Frontend Engineer'
    fill_in 'user_organization', with: 'GitLab'
    submit_settings

    expect(user.reload).to have_attributes(
      skype: 'testskype',
      linkedin: 'testlinkedin',
      twitter: 'testtwitter',
      website_url: 'http://testurl.com',
      bio: 'I <3 GitLab :tada:',
      job_title: 'Frontend Engineer',
      organization: 'GitLab'
    )

    expect(find('#user_location').value).to eq 'Ukraine'
    expect(page).to have_content('Profile was successfully updated')
  end

  it 'does not set secondary emails without user input' do
    fill_in 'user_organization', with: 'GitLab'
    submit_settings

    user.reload
    expect(page).to have_field('user_commit_email', with: '')
    expect(page).to have_field('user_public_email', with: '')

    User::SECONDARY_EMAIL_ATTRIBUTES.each do |attribute|
      expect(user.read_attribute(attribute)).to be_blank
    end
  end

  it 'shows an error if the full name contains an emoji', :js do
    simulate_input('#user_name', 'Martin 😀')
    submit_settings

    page.within('.rspec-full-name') do
      expect(page).to have_css '.gl-field-error-outline'
      expect(find('.gl-field-error')).not_to have_selector('.hidden')
      expect(find('.gl-field-error')).to have_content('Using emojis in names seems fun, but please try to set a status message instead')
    end
  end

  it 'shows an error if the website url is not valid' do
    fill_in 'user_website_url', with: 'admin@gitlab.com'
    submit_settings

    expect(user.reload).to have_attributes(
      website_url: ''
    )

    expect(page).to have_content('Website url is not a valid URL')
  end

  describe 'when I change my email', :js do
    before do
      user.send_reset_password_instructions
    end

    it 'will prompt to confirm my password' do
      expect(user.reset_password_token?).to be true

      update_user_email

      expect(page).to have_selector('[data-testid="password-prompt-modal"]')
    end

    context 'when prompted to confirm password' do
      before do
        update_user_email
      end

      it 'with the correct password successfully updates' do
        confirm_password(user.password)

        expect(page).to have_text("Profile was successfully updated")
      end

      it 'with the incorrect password fails to update' do
        confirm_password("Fake password")

        expect(page).to have_text("Invalid password")
      end
    end

    it 'clears the reset password token' do
      expect(user.reset_password_token?).to be true

      update_user_email
      confirm_password(user.password)

      user.reload
      expect(user.confirmation_token).not_to be_nil
      expect(user.reset_password_token?).to be false
    end
  end

  context 'user avatar' do
    before do
      attach_file(:user_avatar, Rails.root.join('spec', 'fixtures', 'banana_sample.gif'))
      submit_settings
    end

    it 'changes user avatar' do
      expect(page).to have_link('Remove avatar')

      user.reload
      expect(user.avatar).to be_instance_of AvatarUploader
      expect(user.avatar.url).to eq "/uploads/-/system/user/avatar/#{user.id}/banana_sample.gif"
    end

    it 'removes user avatar' do
      click_link 'Remove avatar'

      user.reload

      expect(user.avatar?).to eq false
      expect(page).not_to have_link('Remove avatar')
      expect(page).to have_link('gravatar.com')
    end
  end

  context 'user status', :js do
    def select_emoji(emoji_name, is_modal = false)
      toggle_button = find('.emoji-menu-toggle-button')
      toggle_button.click
      emoji_button = find("gl-emoji[data-name=\"#{emoji_name}\"]")
      emoji_button.click
    end

    context 'profile edit form' do
      it 'shows the user status form' do
        expect(page).to have_content('Current status')
      end

      it 'adds emoji to user status' do
        emoji = 'biohazard'
        select_emoji(emoji)
        submit_settings

        visit_user

        within('.cover-status') do
          expect(page).to have_emoji(emoji)
        end
      end

      it 'adds message to user status' do
        message = 'I have something to say'
        fill_in 'js-status-message-field', with: message
        submit_settings

        visit_user

        within('.cover-status') do
          expect(page).to have_emoji('speech_balloon')
          expect(page).to have_content message
        end
      end

      it 'adds message and emoji to user status' do
        emoji = '8ball'
        message = 'Playing outside'
        select_emoji(emoji)
        fill_in 'js-status-message-field', with: message
        submit_settings

        visit_user

        within('.cover-status') do
          expect(page).to have_emoji(emoji)
          expect(page).to have_content message
        end
      end

      it 'clears the user status' do
        user_status = create(:user_status, user: user, message: 'Eating bread', emoji: 'stuffed_flatbread')

        visit_user

        within('.cover-status') do
          expect(page).to have_emoji(user_status.emoji)
          expect(page).to have_content user_status.message
        end

        visit(profile_path)
        click_button 'js-clear-user-status-button'
        submit_settings

        visit_user

        expect(page).not_to have_selector '.cover-status'
      end

      it 'displays a default emoji if only message is entered' do
        message = 'a status without emoji'
        fill_in 'js-status-message-field', with: message

        within('.js-toggle-emoji-menu') do
          expect(page).to have_emoji('speech_balloon')
        end
      end

      it 'sets the users status to busy' do
        busy_status = find('[data-testid="user-availability-checkbox"]')

        expect(busy_status.checked?).to eq(false)

        toggle_busy_status
        submit_settings
        visit profile_path

        expect(busy_status.checked?).to eq(true)
      end

      context 'with user status set to busy' do
        let(:project) { create(:project, :public) }
        let(:issue) { create(:issue, project: project, author: user) }

        before do
          toggle_busy_status
          submit_settings

          project.add_developer(user)
          visit project_issue_path(project, issue)
        end

        it 'shows author as busy in the assignee dropdown' do
          page.within('.assignee') do
            click_button('Edit')
            wait_for_requests
          end

          page.within '.dropdown-menu-user' do
            expect(page).to have_content("#{user.name} (Busy)")
          end
        end

        it 'displays the assignee busy status' do
          click_button 'assign yourself'
          wait_for_requests

          visit project_issue_path(project, issue)
          wait_for_requests

          expect(page.find('.issuable-assignees')).to have_content("#{user.name} (Busy)")
        end
      end
    end

    context 'user menu' do
      let(:issue) { create(:issue, project: project)}
      let(:project) { create(:project) }

      def open_modal(button_text)
        find('.header-user-dropdown-toggle').click

        page.within ".header-user" do
          click_button button_text
        end
      end

      def open_user_status_modal
        open_modal 'Set status'
      end

      def open_edit_status_modal
        open_modal 'Edit status'
      end

      def set_user_status_in_modal
        page.within "#set-user-status-modal" do
          click_button 'Set status'
        end
        wait_for_requests
      end

      before do
        visit root_path(user)
      end

      it 'shows the "Set status" menu item in the user menu' do
        find('.header-user-dropdown-toggle').click

        page.within ".header-user" do
          expect(page).to have_content('Set status')
        end
      end

      it 'shows the "Edit status" menu item in the user menu' do
        user_status = create(:user_status, user: user, message: 'Eating bread', emoji: 'stuffed_flatbread')
        visit root_path(user)

        find('.header-user-dropdown-toggle').click

        page.within ".header-user" do
          expect(page).to have_emoji(user_status.emoji)
          expect(page).to have_content user_status.message
          expect(page).to have_content('Edit status')
        end
      end

      it 'shows user status modal' do
        open_user_status_modal

        expect(page.find('#set-user-status-modal')).to be_visible
        expect(page).to have_content('Set a status')
      end

      it 'adds emoji to user status' do
        emoji = '8ball'
        open_user_status_modal
        select_emoji(emoji, true)
        set_user_status_in_modal

        visit_user

        within('.cover-status') do
          expect(page).to have_emoji(emoji)
        end
      end

      it 'sets the users status to busy' do
        open_user_status_modal
        busy_status = find('[data-testid="user-availability-checkbox"]')

        expect(busy_status.checked?).to eq(false)

        toggle_busy_status
        set_user_status_in_modal

        wait_for_requests
        visit root_path(user)

        open_edit_status_modal

        expect(busy_status.checked?).to eq(true)
      end

      it 'opens the emoji modal again after closing it' do
        open_user_status_modal
        select_emoji('8ball', true)

        find('.emoji-menu-toggle-button').click

        expect(page).to have_selector('.emoji-picker-emoji')
      end

      it 'does not update the awards panel emoji' do
        project.add_maintainer(user)
        visit(project_issue_path(project, issue))

        emoji = '8ball'
        open_user_status_modal
        select_emoji(emoji, true)

        expect(page.all('.award-control .js-counter')).to all(have_content('0'))
      end

      it 'adds message to user status' do
        message = 'I have something to say'
        open_user_status_modal
        find('.js-status-message-field').native.send_keys(message)
        set_user_status_in_modal

        visit_user

        within('.cover-status') do
          expect(page).to have_emoji('speech_balloon')
          expect(page).to have_content message
        end
      end

      it 'adds message and emoji to user status' do
        emoji = '8ball'
        message = 'Playing outside'
        open_user_status_modal
        select_emoji(emoji, true)
        find('.js-status-message-field').native.send_keys(message)
        set_user_status_in_modal

        visit_user

        within('.cover-status') do
          expect(page).to have_emoji(emoji)
          expect(page).to have_content message
        end
      end

      it 'clears the user status with the "X" button' do
        user_status = create(:user_status, user: user, message: 'Eating bread', emoji: 'stuffed_flatbread')

        visit_user
        wait_for_requests

        within('.cover-status') do
          expect(page).to have_emoji(user_status.emoji)
          expect(page).to have_content user_status.message
        end

        open_edit_status_modal

        find('.js-clear-user-status-button').click
        set_user_status_in_modal

        visit_user
        wait_for_requests

        expect(page).not_to have_selector '.cover-status'
      end

      context 'Remove status button' do
        before do
          user.status = UserStatus.new(message: 'Eating bread', emoji: 'stuffed_flatbread')

          visit_user
          wait_for_requests

          open_edit_status_modal

          page.within "#set-user-status-modal" do
            click_button 'Remove status'
          end

          wait_for_requests
        end

        it 'clears the user status with the "Remove status" button' do
          visit_user

          expect(page).not_to have_selector '.cover-status'
        end

        it 'shows the "Set status" menu item in the user menu' do
          visit root_path(user)

          find('.header-user-dropdown-toggle').click

          page.within ".header-user" do
            expect(page).to have_content('Set status')
          end
        end
      end

      it 'displays a default emoji if only message is entered' do
        message = 'a status without emoji'
        open_user_status_modal
        find('.js-status-message-field').native.send_keys(message)

        expect(page).to have_emoji('speech_balloon')
      end

      context 'note header' do
        let(:project) { create(:project_empty_repo, :public) }
        let(:issue) { create(:issue, project: project) }
        let(:emoji) { "stuffed_flatbread" }

        before do
          project.add_guest(user)
          create(:user_status, user: user, message: 'Taking notes', emoji: emoji)

          visit(project_issue_path(project, issue))

          add_note("This is a comment")
          visit(project_issue_path(project, issue))

          wait_for_requests
        end

        it 'displays the status emoji' do
          first_note = page.find_all(".main-notes-list .timeline-entry").first

          expect(first_note).to have_emoji(emoji)
        end

        it 'clears the status emoji' do
          open_edit_status_modal

          page.within "#set-user-status-modal" do
            click_button 'Remove status'
          end

          visit(project_issue_path(project, issue))
          wait_for_requests

          first_note = page.find_all(".main-notes-list .timeline-entry").first

          expect(first_note).not_to have_css('.user-status-emoji')
        end
      end
    end

    context 'User time preferences', :js do
      let(:issue) { create(:issue, project: project)}
      let(:project) { create(:project) }

      before do
        stub_feature_flags(user_time_settings: true)
      end

      it 'shows the user time preferences form' do
        expect(page).to have_content('Time settings')
      end

      it 'allows the user to select a time zone from a dropdown list of options' do
        expect(page.find('.user-time-preferences .dropdown')).not_to have_css('.show')

        page.find('.user-time-preferences .js-timezone-dropdown').click

        expect(page.find('.user-time-preferences .dropdown')).to have_css('.show')

        page.find("a", text: "Nuku'alofa").click

        expect(page).to have_field(:user_timezone, with: 'Pacific/Tongatapu', type: :hidden)
      end

      it 'timezone defaults to empty' do
        expect(page).to have_field(:user_timezone, with: '', type: :hidden)
      end
    end
  end

  context 'work information', :js do
    context 'when job title and organziation are entered' do
      it "shows job title and organzation on user's profile" do
        fill_in 'user_job_title', with: 'Frontend Engineer'
        fill_in 'user_organization', with: 'GitLab - work info test'
        submit_settings

        visit_user

        expect(page).to have_content('Frontend Engineer at GitLab - work info test')
      end
    end

    context 'when only job title is entered' do
      it "shows only job title on user's profile" do
        fill_in 'user_job_title', with: 'Frontend Engineer - work info test'
        submit_settings

        visit_user

        expect(page).to have_content('Frontend Engineer - work info test')
      end
    end

    context 'when only organization is entered' do
      it "shows only organization on user's profile" do
        fill_in 'user_organization', with: 'GitLab - work info test'
        submit_settings

        visit_user

        expect(page).to have_content('GitLab - work info test')
      end
    end
  end
end
