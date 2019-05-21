require 'spec_helper'

describe 'Login' do
  include TermsHelper
  include UserLoginHelper

  before do
    stub_authentication_activity_metrics(debug: true)
  end

  describe 'password reset token after successful sign in' do
    it 'invalidates password reset token' do
      expect(authentication_metrics)
        .to increment(:user_authenticated_counter)

      user = create(:user)

      expect(user.reset_password_token).to be_nil

      visit new_user_password_path
      fill_in 'user_email', with: user.email
      click_button 'Reset password'

      user.reload
      expect(user.reset_password_token).not_to be_nil

      find('a[href="#login-pane"]').click
      gitlab_sign_in(user)
      expect(current_path).to eq root_path

      user.reload
      expect(user.reset_password_token).to be_nil
    end
  end

  describe 'initial login after setup' do
    it 'allows the initial admin to create a password' do
      expect(authentication_metrics)
        .to increment(:user_authenticated_counter)

      # This behavior is dependent on there only being one user
      User.delete_all

      user = create(:admin, password_automatically_set: true)

      visit root_path
      expect(current_path).to eq edit_user_password_path
      expect(page).to have_content('Please create a password for your new account.')

      fill_in 'user_password',              with: 'password'
      fill_in 'user_password_confirmation', with: 'password'
      click_button 'Change your password'

      expect(current_path).to eq new_user_session_path
      expect(page).to have_content(I18n.t('devise.passwords.updated_not_active'))

      fill_in 'user_login',    with: user.username
      fill_in 'user_password', with: 'password'
      click_button 'Sign in'

      expect(current_path).to eq root_path
    end

    it 'does not show flash messages when login page' do
      visit root_path
      expect(page).not_to have_content('You need to sign in or sign up before continuing.')
    end
  end

  describe 'with a blocked account' do
    it 'prevents the user from logging in' do
      expect(authentication_metrics)
        .to increment(:user_blocked_counter)
        .and increment(:user_unauthenticated_counter)
        .and increment(:user_session_destroyed_counter).twice

      user = create(:user, :blocked)

      gitlab_sign_in(user)

      expect(page).to have_content('Your account has been blocked.')
    end

    it 'does not update Devise trackable attributes', :clean_gitlab_redis_shared_state do
      expect(authentication_metrics)
        .to increment(:user_blocked_counter)
        .and increment(:user_unauthenticated_counter)
        .and increment(:user_session_destroyed_counter).twice

      user = create(:user, :blocked)

      expect { gitlab_sign_in(user) }.not_to change { user.reload.sign_in_count }
    end
  end

  describe 'with the ghost user' do
    it 'disallows login' do
      expect(authentication_metrics)
        .to increment(:user_unauthenticated_counter)
        .and increment(:user_password_invalid_counter)

      gitlab_sign_in(User.ghost)

      expect(page).to have_content('Invalid Login or password.')
    end

    it 'does not update Devise trackable attributes', :clean_gitlab_redis_shared_state do
      expect(authentication_metrics)
        .to increment(:user_unauthenticated_counter)
        .and increment(:user_password_invalid_counter)

      expect { gitlab_sign_in(User.ghost) }
        .not_to change { User.ghost.reload.sign_in_count }
    end
  end

  describe 'with two-factor authentication' do
    def enter_code(code)
      fill_in 'user_otp_attempt', with: code
      click_button 'Verify code'
    end

    context 'with valid username/password' do
      let(:user) { create(:user, :two_factor) }

      before do
        gitlab_sign_in(user, remember: true)

        expect(page).to have_content('Two-Factor Authentication')
      end

      it 'does not show a "You are already signed in." error message' do
        expect(authentication_metrics)
          .to increment(:user_authenticated_counter)
          .and increment(:user_session_override_counter)
          .and increment(:user_two_factor_authenticated_counter)

        enter_code(user.current_otp)

        expect(page).not_to have_content(I18n.t('devise.failure.already_authenticated'))
      end

      context 'using one-time code' do
        it 'allows login with valid code' do
          expect(authentication_metrics)
            .to increment(:user_authenticated_counter)
            .and increment(:user_session_override_counter)
            .and increment(:user_two_factor_authenticated_counter)

          enter_code(user.current_otp)

          expect(current_path).to eq root_path
        end

        it 'persists remember_me value via hidden field' do
          field = first('input#user_remember_me', visible: false)

          expect(field.value).to eq '1'
        end

        it 'blocks login with invalid code' do
          # TODO invalid 2FA code does not generate any events
          # See gitlab-org/gitlab-ce#49785

          enter_code('foo')

          expect(page).to have_content('Invalid two-factor code')
        end

        it 'allows login with invalid code, then valid code' do
          expect(authentication_metrics)
            .to increment(:user_authenticated_counter)
            .and increment(:user_session_override_counter)
            .and increment(:user_two_factor_authenticated_counter)

          enter_code('foo')
          expect(page).to have_content('Invalid two-factor code')

          enter_code(user.current_otp)
          expect(current_path).to eq root_path
        end
      end

      context 'using backup code' do
        let(:codes) { user.generate_otp_backup_codes! }

        before do
          expect(codes.size).to eq 10

          # Ensure the generated codes get saved
          user.save
        end

        context 'with valid code' do
          it 'allows login' do
            expect(authentication_metrics)
              .to increment(:user_authenticated_counter)
              .and increment(:user_session_override_counter)
              .and increment(:user_two_factor_authenticated_counter)

            enter_code(codes.sample)

            expect(current_path).to eq root_path
          end

          it 'invalidates the used code' do
            expect(authentication_metrics)
              .to increment(:user_authenticated_counter)
              .and increment(:user_session_override_counter)
              .and increment(:user_two_factor_authenticated_counter)

            expect { enter_code(codes.sample) }
              .to change { user.reload.otp_backup_codes.size }.by(-1)
          end

          it 'invalidates backup codes twice in a row' do
            expect(authentication_metrics)
              .to increment(:user_authenticated_counter).twice
              .and increment(:user_session_override_counter).twice
              .and increment(:user_two_factor_authenticated_counter).twice
              .and increment(:user_session_destroyed_counter)

            random_code = codes.delete(codes.sample)
            expect { enter_code(random_code) }
              .to change { user.reload.otp_backup_codes.size }.by(-1)

            gitlab_sign_out
            gitlab_sign_in(user)

            expect { enter_code(codes.sample) }
              .to change { user.reload.otp_backup_codes.size }.by(-1)
          end
        end

        context 'with invalid code' do
          it 'blocks login' do
            # TODO, invalid two factor authentication does not increment
            # metrics / counters, see gitlab-org/gitlab-ce#49785

            code = codes.sample
            expect(user.invalidate_otp_backup_code!(code)).to eq true

            user.save!
            expect(user.reload.otp_backup_codes.size).to eq 9

            enter_code(code)
            expect(page).to have_content('Invalid two-factor code.')
          end
        end
      end
    end

    context 'when logging in via OAuth' do
      let(:user) { create(:omniauth_user, :two_factor, extern_uid: 'my-uid', provider: 'saml')}
      let(:mock_saml_response) do
        File.read('spec/fixtures/authentication/saml_response.xml')
      end

      before do
        stub_omniauth_saml_config(enabled: true, auto_link_saml_user: true, allow_single_sign_on: ['saml'],
                                  providers: [mock_saml_config_with_upstream_two_factor_authn_contexts])
      end

      context 'when authn_context is worth two factors' do
        let(:mock_saml_response) do
          File.read('spec/fixtures/authentication/saml_response.xml')
              .gsub('urn:oasis:names:tc:SAML:2.0:ac:classes:Password',
                    'urn:oasis:names:tc:SAML:2.0:ac:classes:SecondFactorOTPSMS')
        end

        it 'signs user in without prompting for second factor' do
          # TODO, OAuth authentication does not fire events,
          # see gitlab-org/gitlab-ce#49786

          expect(authentication_metrics)
            .to increment(:user_authenticated_counter)
            .and increment(:user_session_override_counter)

          sign_in_using_saml!

          expect(page).not_to have_content('Two-Factor Authentication')
          expect(current_path).to eq root_path
        end
      end

      context 'when two factor authentication is required' do
        it 'shows 2FA prompt after OAuth login' do
          expect(authentication_metrics)
            .to increment(:user_authenticated_counter)
            .and increment(:user_session_override_counter)
            .and increment(:user_two_factor_authenticated_counter)

          sign_in_using_saml!

          expect(page).to have_content('Two-Factor Authentication')

          enter_code(user.current_otp)

          expect(current_path).to eq root_path
        end
      end

      def sign_in_using_saml!
        gitlab_sign_in_via('saml', user, 'my-uid', mock_saml_response)
      end
    end
  end

  describe 'without two-factor authentication' do
    context 'with correct username and password' do
      let(:user) { create(:user) }

      it 'allows basic login' do
        expect(authentication_metrics)
          .to increment(:user_authenticated_counter)

        gitlab_sign_in(user)

        expect(current_path).to eq root_path
        expect(page).not_to have_content(I18n.t('devise.failure.already_authenticated'))
      end

      it 'does not show already signed in message when opening sign in page after login' do
        expect(authentication_metrics)
          .to increment(:user_authenticated_counter)

        gitlab_sign_in(user)
        visit new_user_session_path

        expect(page).not_to have_content(I18n.t('devise.failure.already_authenticated'))
      end
    end

    context 'with invalid username and password' do
      let(:user) { create(:user, password: 'not-the-default') }

      it 'blocks invalid login' do
        expect(authentication_metrics)
          .to increment(:user_unauthenticated_counter)
          .and increment(:user_password_invalid_counter)

        gitlab_sign_in(user)

        expect(page).to have_content('Invalid Login or password.')
      end
    end
  end

  describe 'with required two-factor authentication enabled' do
    let(:user) { create(:user) }
    #  TODO: otp_grace_period_started_at

    context 'global setting' do
      before do
        stub_application_setting(require_two_factor_authentication: true)
      end

      context 'with grace period defined' do
        before do
          stub_application_setting(two_factor_grace_period: 48)
        end

        context 'within the grace period' do
          it 'redirects to two-factor configuration page' do
            expect(authentication_metrics)
              .to increment(:user_authenticated_counter)

            gitlab_sign_in(user)

            expect(current_path).to eq profile_two_factor_auth_path
            expect(page).to have_content('The global settings require you to enable Two-Factor Authentication for your account. You need to do this before ')
          end

          it 'allows skipping two-factor configuration', :js do
            expect(authentication_metrics)
              .to increment(:user_authenticated_counter)

            gitlab_sign_in(user)

            expect(current_path).to eq profile_two_factor_auth_path
            click_link 'Configure it later'
            expect(current_path).to eq root_path
          end
        end

        context 'after the grace period' do
          let(:user) { create(:user, otp_grace_period_started_at: 9999.hours.ago) }

          it 'redirects to two-factor configuration page' do
            expect(authentication_metrics)
              .to increment(:user_authenticated_counter)

            gitlab_sign_in(user)

            expect(current_path).to eq profile_two_factor_auth_path
            expect(page).to have_content(
              'The global settings require you to enable Two-Factor Authentication for your account.'
            )
          end

          it 'disallows skipping two-factor configuration', :js do
            expect(authentication_metrics)
              .to increment(:user_authenticated_counter)

            gitlab_sign_in(user)

            expect(current_path).to eq profile_two_factor_auth_path
            expect(page).not_to have_link('Configure it later')
          end
        end
      end

      context 'without grace period defined' do
        before do
          stub_application_setting(two_factor_grace_period: 0)
        end

        it 'redirects to two-factor configuration page' do
          expect(authentication_metrics)
            .to increment(:user_authenticated_counter)

          gitlab_sign_in(user)

          expect(current_path).to eq profile_two_factor_auth_path
          expect(page).to have_content(
            'The global settings require you to enable Two-Factor Authentication for your account.'
          )
        end
      end
    end

    context 'group setting' do
      before do
        group1 = create :group, name: 'Group 1', require_two_factor_authentication: true
        group1.add_user(user, GroupMember::DEVELOPER)
        group2 = create :group, name: 'Group 2', require_two_factor_authentication: true
        group2.add_user(user, GroupMember::DEVELOPER)
      end

      context 'with grace period defined' do
        before do
          stub_application_setting(two_factor_grace_period: 48)
        end

        context 'within the grace period' do
          it 'redirects to two-factor configuration page' do
            Timecop.freeze do
              expect(authentication_metrics)
                .to increment(:user_authenticated_counter)

              gitlab_sign_in(user)

              expect(current_path).to eq profile_two_factor_auth_path
              expect(page).to have_content(
                'The group settings for Group 1 and Group 2 require you to enable '\
                'Two-Factor Authentication for your account. '\
                'You can leave Group 1 and leave Group 2. '\
                'You need to do this '\
                'before '\
                "#{(Time.zone.now + 2.days).strftime("%a, %d %b %Y %H:%M:%S %z")}"
              )
            end
          end

          it 'allows skipping two-factor configuration', :js do
            expect(authentication_metrics)
              .to increment(:user_authenticated_counter)

            gitlab_sign_in(user)

            expect(current_path).to eq profile_two_factor_auth_path
            click_link 'Configure it later'
            expect(current_path).to eq root_path
          end
        end

        context 'after the grace period' do
          let(:user) { create(:user, otp_grace_period_started_at: 9999.hours.ago) }

          it 'redirects to two-factor configuration page' do
            expect(authentication_metrics)
              .to increment(:user_authenticated_counter)

            gitlab_sign_in(user)

            expect(current_path).to eq profile_two_factor_auth_path
            expect(page).to have_content(
              'The group settings for Group 1 and Group 2 require you to enable ' \
              'Two-Factor Authentication for your account.'
            )
          end

          it 'disallows skipping two-factor configuration', :js do
            expect(authentication_metrics)
              .to increment(:user_authenticated_counter)

            gitlab_sign_in(user)

            expect(current_path).to eq profile_two_factor_auth_path
            expect(page).not_to have_link('Configure it later')
          end
        end
      end

      context 'without grace period defined' do
        before do
          stub_application_setting(two_factor_grace_period: 0)
        end

        it 'redirects to two-factor configuration page' do
          expect(authentication_metrics)
            .to increment(:user_authenticated_counter)

          gitlab_sign_in(user)

          expect(current_path).to eq profile_two_factor_auth_path
          expect(page).to have_content(
            'The group settings for Group 1 and Group 2 require you to enable ' \
            'Two-Factor Authentication for your account. '\
            'You can leave Group 1 and leave Group 2.'
          )
        end
      end
    end
  end

  describe 'UI tabs and panes' do
    context 'when no defaults are changed' do
      it 'correctly renders tabs and panes' do
        ensure_tab_pane_correctness
      end
    end

    context 'when signup is disabled' do
      before do
        stub_application_setting(signup_enabled: false)
      end

      it 'correctly renders tabs and panes' do
        ensure_tab_pane_correctness
      end
    end

    context 'when ldap is enabled' do
      before do
        visit new_user_session_path
        allow(page).to receive(:form_based_providers).and_return([:ldapmain])
        allow(page).to receive(:ldap_enabled).and_return(true)
      end

      it 'correctly renders tabs and panes' do
        ensure_tab_pane_correctness(false)
      end
    end

    context 'when crowd is enabled' do
      before do
        visit new_user_session_path
        allow(page).to receive(:form_based_providers).and_return([:crowd])
        allow(page).to receive(:crowd_enabled?).and_return(true)
      end

      it 'correctly renders tabs and panes' do
        ensure_tab_pane_correctness(false)
      end
    end
  end

  context 'when terms are enforced' do
    let(:user) { create(:user) }

    before do
      enforce_terms
    end

    it 'asks to accept the terms on first login' do
      expect(authentication_metrics)
        .to increment(:user_authenticated_counter)

      visit new_user_session_path

      fill_in 'user_login', with: user.email
      fill_in 'user_password', with: '12345678'

      click_button 'Sign in'

      expect_to_be_on_terms_page

      click_button 'Accept terms'

      expect(current_path).to eq(root_path)
      expect(page).not_to have_content(I18n.t('devise.failure.already_authenticated'))
    end

    it 'does not ask for terms when the user already accepted them' do
      expect(authentication_metrics)
        .to increment(:user_authenticated_counter)

      accept_terms(user)

      visit new_user_session_path

      fill_in 'user_login', with: user.email
      fill_in 'user_password', with: '12345678'

      click_button 'Sign in'

      expect(current_path).to eq(root_path)
    end

    context 'when 2FA is required for the user' do
      before do
        group = create(:group, require_two_factor_authentication: true)
        group.add_developer(user)
      end

      context 'when the user did not enable 2FA' do
        it 'asks to set 2FA before asking to accept the terms' do
          expect(authentication_metrics)
            .to increment(:user_authenticated_counter)

          visit new_user_session_path

          fill_in 'user_login', with: user.email
          fill_in 'user_password', with: '12345678'

          click_button 'Sign in'

          expect_to_be_on_terms_page
          click_button 'Accept terms'

          expect(current_path).to eq(profile_two_factor_auth_path)

          fill_in 'pin_code', with: user.reload.current_otp

          click_button 'Register with two-factor app'
          click_link 'Proceed'

          expect(current_path).to eq(profile_account_path)
        end
      end

      context 'when the user already enabled 2FA' do
        before do
          user.update!(otp_required_for_login: true,
                       otp_secret:  User.generate_otp_secret(32))
        end

        it 'asks the user to accept the terms' do
          expect(authentication_metrics)
            .to increment(:user_authenticated_counter)
            .and increment(:user_session_override_counter)
            .and increment(:user_two_factor_authenticated_counter)

          visit new_user_session_path

          fill_in 'user_login', with: user.email
          fill_in 'user_password', with: '12345678'
          click_button 'Sign in'

          fill_in 'user_otp_attempt', with: user.reload.current_otp
          click_button 'Verify code'

          expect_to_be_on_terms_page
          click_button 'Accept terms'

          expect(current_path).to eq(root_path)
        end
      end
    end

    context 'when the users password is expired' do
      before do
        user.update!(password_expires_at: Time.parse('2018-05-08 11:29:46 UTC'))
      end

      it 'asks the user to accept the terms before setting a new password' do
        expect(authentication_metrics)
          .to increment(:user_authenticated_counter)

        visit new_user_session_path

        fill_in 'user_login', with: user.email
        fill_in 'user_password', with: '12345678'
        click_button 'Sign in'

        expect_to_be_on_terms_page
        click_button 'Accept terms'

        expect(current_path).to eq(new_profile_password_path)

        fill_in 'user_current_password', with: '12345678'
        fill_in 'user_password', with: 'new password'
        fill_in 'user_password_confirmation', with: 'new password'
        click_button 'Set new password'

        expect(page).to have_content('Password successfully changed')
      end
    end

    context 'when the user does not have an email configured' do
      let(:user) { create(:omniauth_user, extern_uid: 'my-uid', provider: 'saml', email: 'temp-email-for-oauth-user@gitlab.localhost') }

      before do
        stub_omniauth_saml_config(enabled: true, auto_link_saml_user: true, allow_single_sign_on: ['saml'], providers: [mock_saml_config])
      end

      it 'asks the user to accept the terms before setting an email' do
        expect(authentication_metrics)
          .to increment(:user_authenticated_counter)
          .and increment(:user_session_override_counter)

        gitlab_sign_in_via('saml', user, 'my-uid')

        expect_to_be_on_terms_page
        click_button 'Accept terms'

        expect(current_path).to eq(profile_path)

        fill_in 'Email', with: 'hello@world.com'

        click_button 'Update profile settings'

        expect(page).to have_content('Profile was successfully updated')
      end
    end
  end
end
