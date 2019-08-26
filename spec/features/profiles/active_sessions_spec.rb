# frozen_string_literal: true

require 'rails_helper'

describe 'Profile > Active Sessions', :clean_gitlab_redis_shared_state do
  let(:user) do
    create(:user).tap do |user|
      user.current_sign_in_at = Time.current
    end
  end

  let(:admin) { create(:admin) }

  around do |example|
    Timecop.freeze(Time.zone.parse('2018-03-12 09:06')) do
      example.run
    end
  end

  it 'User sees their active sessions' do
    Capybara::Session.new(:session1)
    Capybara::Session.new(:session2)
    Capybara::Session.new(:session3)

    # note: headers can only be set on the non-js (aka. rack-test) driver
    using_session :session1 do
      Capybara.page.driver.header(
        'User-Agent',
        'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:58.0) Gecko/20100101 Firefox/58.0'
      )

      gitlab_sign_in(user)
    end

    # set an additional session on another device
    using_session :session2 do
      Capybara.page.driver.header(
        'User-Agent',
        'Mozilla/5.0 (iPhone; CPU iPhone OS 8_1_3 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Mobile/12B466 [FBDV/iPhone7,2]'
      )

      gitlab_sign_in(user)
    end

    # set an admin session impersonating the user
    using_session :session3 do
      Capybara.page.driver.header(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 Safari/537.36'
      )

      gitlab_sign_in(admin)

      visit admin_user_path(user)

      click_link 'Impersonate'
    end

    using_session :session1 do
      visit profile_active_sessions_path

      expect(page).to(
        have_selector('ul.list-group li.list-group-item', { text: 'Signed in on',
                                                            count: 2 }))

      expect(page).to have_content(
        '127.0.0.1 ' \
        'This is your current session ' \
        'Firefox on Ubuntu ' \
        'Signed in on 12 Mar 09:06'
      )

      expect(page).to have_selector '[title="Desktop"]', count: 1

      expect(page).to have_content(
        '127.0.0.1 ' \
        'Last accessed on 12 Mar 09:06 ' \
        'Mobile Safari on iOS ' \
        'Signed in on 12 Mar 09:06'
      )

      expect(page).to have_selector '[title="Smartphone"]', count: 1

      expect(page).not_to have_content('Chrome on Windows')
    end
  end
end
