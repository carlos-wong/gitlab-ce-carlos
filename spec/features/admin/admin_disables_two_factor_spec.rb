# frozen_string_literal: true

require 'rails_helper'

describe 'Admin disables 2FA for a user' do
  it 'successfully', :js do
    sign_in(create(:admin))
    user = create(:user, :two_factor)

    edit_user(user)
    page.within('.two-factor-status') do
      accept_confirm { click_link 'Disable' }
    end

    page.within('.two-factor-status') do
      expect(page).to have_content 'Disabled'
      expect(page).not_to have_button 'Disable'
    end
  end

  it 'for a user without 2FA enabled' do
    sign_in(create(:admin))
    user = create(:user)

    edit_user(user)

    page.within('.two-factor-status') do
      expect(page).not_to have_button 'Disable'
    end
  end

  def edit_user(user)
    visit admin_user_path(user)
  end
end
