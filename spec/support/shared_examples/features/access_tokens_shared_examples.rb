# frozen_string_literal: true

RSpec.shared_examples 'resource access tokens missing access rights' do
  it 'does not show access token page' do
    visit resource_settings_access_tokens_path

    expect(page).to have_content("Page Not Found")
  end
end

RSpec.shared_examples 'resource access tokens creation' do |resource_type|
  def active_resource_access_tokens
    find('.table.active-tokens')
  end

  def created_resource_access_token
    find('#created-personal-access-token').value
  end

  it 'allows creation of an access token', :aggregate_failures do
    name = 'My access token'

    visit resource_settings_access_tokens_path
    fill_in 'Token name', with: name

    # Set date to 1st of next month
    find_field('Expiration date').click
    find('.pika-next').click
    click_on '1'

    # Scopes
    check 'read_api'
    check 'read_repository'

    click_on "Create #{resource_type} access token"

    expect(active_resource_access_tokens).to have_text(name)
    expect(active_resource_access_tokens).to have_text('in')
    expect(active_resource_access_tokens).to have_text('read_api')
    expect(active_resource_access_tokens).to have_text('read_repository')
    expect(active_resource_access_tokens).to have_text('Maintainer')
    expect(created_resource_access_token).not_to be_empty
  end
end

RSpec.shared_examples 'resource access tokens creation disallowed' do |error_message|
  before do
    group.namespace_settings.update_column(:resource_access_token_creation_allowed, false)
  end

  it 'does not show access token creation form' do
    visit resource_settings_access_tokens_path

    expect(page).not_to have_selector('#new_resource_access_token')
  end

  it 'shows access token creation disabled text' do
    visit resource_settings_access_tokens_path

    expect(page).to have_text(error_message)
  end

  context 'group settings link' do
    context 'when user is not a group owner' do
      before do
        group.add_developer(user)
      end

      it 'does not show group settings link' do
        visit resource_settings_access_tokens_path

        expect(page).not_to have_link('group settings', href: edit_group_path(group))
      end
    end

    context 'with nested groups' do
      let(:parent_group) { create(:group) }
      let(:group) { create(:group, parent: parent_group) }

      context 'when user is not a top level group owner' do
        before do
          group.add_owner(user)
        end

        it 'does not show group settings link' do
          visit resource_settings_access_tokens_path

          expect(page).not_to have_link('group settings', href: edit_group_path(group))
        end
      end
    end

    context 'when user is a group owner' do
      before do
        group.add_owner(user)
      end

      it 'shows group settings link' do
        visit resource_settings_access_tokens_path

        expect(page).to have_link('group settings', href: edit_group_path(group))
      end
    end
  end
end

RSpec.shared_examples 'active resource access tokens' do
  def active_resource_access_tokens
    find('.table.active-tokens')
  end

  it 'shows active access tokens' do
    visit resource_settings_access_tokens_path

    expect(active_resource_access_tokens).to have_text(resource_access_token.name)
  end

  context 'when User#time_display_relative is false' do
    before do
      user.update!(time_display_relative: false)
    end

    it 'shows absolute times for expires_at' do
      visit resource_settings_access_tokens_path

      expect(active_resource_access_tokens).to have_text(PersonalAccessToken.last.expires_at.strftime('%b %-d'))
    end
  end
end

RSpec.shared_examples 'inactive resource access tokens' do |no_active_tokens_text|
  def no_resource_access_tokens_message
    find('.settings-message')
  end

  it 'allows revocation of an active token' do
    visit resource_settings_access_tokens_path
    accept_confirm { click_on 'Revoke' }

    expect(page).to have_selector('.settings-message')
    expect(no_resource_access_tokens_message).to have_text(no_active_tokens_text)
  end

  it 'removes expired tokens from active section' do
    resource_access_token.update!(expires_at: 5.days.ago)
    visit resource_settings_access_tokens_path

    expect(page).to have_selector('.settings-message')
    expect(no_resource_access_tokens_message).to have_text(no_active_tokens_text)
  end

  context 'when resource access token creation is not allowed' do
    before do
      group.namespace_settings.update_column(:resource_access_token_creation_allowed, false)
    end

    it 'allows revocation of an active token' do
      visit resource_settings_access_tokens_path
      accept_confirm { click_on 'Revoke' }

      expect(page).to have_selector('.settings-message')
      expect(no_resource_access_tokens_message).to have_text(no_active_tokens_text)
    end
  end
end
