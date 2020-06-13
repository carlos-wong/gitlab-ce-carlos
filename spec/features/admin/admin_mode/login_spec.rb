# frozen_string_literal: true

require 'spec_helper'

describe 'Admin Mode Login', :clean_gitlab_redis_shared_state, :do_not_mock_admin_mode do
  include TermsHelper
  include UserLoginHelper

  describe 'with two-factor authentication', :js do
    def enter_code(code)
      fill_in 'user_otp_attempt', with: code
      click_button 'Verify code'
    end

    context 'with valid username/password' do
      let(:user) { create(:admin, :two_factor) }

      context 'using one-time code' do
        it 'blocks login if we reuse the same code immediately' do
          gitlab_sign_in(user, remember: true)

          expect(page).to have_content('Two-Factor Authentication')

          repeated_otp = user.current_otp
          enter_code(repeated_otp)
          gitlab_enable_admin_mode_sign_in(user)

          expect(page).to have_content('Two-Factor Authentication')

          enter_code(repeated_otp)

          expect(current_path).to eq admin_session_path
          expect(page).to have_content('Invalid two-factor code')
        end

        context 'not re-using codes' do
          before do
            gitlab_sign_in(user, remember: true)

            expect(page).to have_content('Two-Factor Authentication')

            enter_code(user.current_otp)
            gitlab_enable_admin_mode_sign_in(user)

            expect(page).to have_content('Two-Factor Authentication')
          end

          it 'allows login with valid code' do
            # Cannot reuse the TOTP
            Timecop.travel(30.seconds.from_now) do
              enter_code(user.current_otp)

              expect(current_path).to eq admin_root_path
              expect(page).to have_content('Admin mode enabled')
            end
          end

          it 'blocks login with invalid code' do
            # Cannot reuse the TOTP
            Timecop.travel(30.seconds.from_now) do
              enter_code('foo')

              expect(page).to have_content('Invalid two-factor code')
            end
          end

          it 'allows login with invalid code, then valid code' do
            # Cannot reuse the TOTP
            Timecop.travel(30.seconds.from_now) do
              enter_code('foo')

              expect(page).to have_content('Invalid two-factor code')

              enter_code(user.current_otp)

              expect(current_path).to eq admin_root_path
              expect(page).to have_content('Admin mode enabled')
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
                enter_code(codes.sample)

                expect(current_path).to eq admin_root_path
                expect(page).to have_content('Admin mode enabled')
              end

              it 'invalidates the used code' do
                expect { enter_code(codes.sample) }
                  .to change { user.reload.otp_backup_codes.size }.by(-1)
              end
            end

            context 'with invalid code' do
              it 'blocks login' do
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
      end

      context 'when logging in via omniauth' do
        let(:user) { create(:omniauth_user, :admin, :two_factor, extern_uid: 'my-uid', provider: 'saml')}
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
            sign_in_using_saml!

            expect(page).not_to have_content('Two-Factor Authentication')

            enable_admin_mode_using_saml!

            expect(page).not_to have_content('Two-Factor Authentication')
            expect(current_path).to eq admin_root_path
            expect(page).to have_content('Admin mode enabled')
          end
        end

        context 'when two factor authentication is required' do
          it 'shows 2FA prompt after omniauth login' do
            sign_in_using_saml!

            expect(page).to have_content('Two-Factor Authentication')
            enter_code(user.current_otp)

            enable_admin_mode_using_saml!

            expect(page).to have_content('Two-Factor Authentication')

            # Cannot reuse the TOTP
            Timecop.travel(30.seconds.from_now) do
              enter_code(user.current_otp)

              expect(current_path).to eq admin_root_path
              expect(page).to have_content('Admin mode enabled')
            end
          end
        end

        def sign_in_using_saml!
          gitlab_sign_in_via('saml', user, 'my-uid', mock_saml_response)
        end

        def enable_admin_mode_using_saml!
          gitlab_enable_admin_mode_sign_in_via('saml', user, 'my-uid', mock_saml_response)
        end
      end
    end
  end
end
