# frozen_string_literal: true

require 'spec_helper'

describe SessionsController do
  include DeviseHelpers

  describe '#new' do
    before do
      set_devise_mapping(context: @request)
    end

    context 'when auto sign-in is enabled' do
      before do
        stub_omniauth_setting(auto_sign_in_with_provider: :saml)
        allow(controller).to receive(:omniauth_authorize_path).with(:user, :saml)
          .and_return('/saml')
      end

      context 'and no auto_sign_in param is passed' do
        it 'redirects to :omniauth_authorize_path' do
          get(:new)

          expect(response).to have_gitlab_http_status(302)
          expect(response).to redirect_to('/saml')
        end
      end

      context 'and auto_sign_in=false param is passed' do
        it 'responds with 200' do
          get(:new, params: { auto_sign_in: 'false' })

          expect(response).to have_gitlab_http_status(200)
        end
      end
    end
  end

  describe '#create' do
    before do
      set_devise_mapping(context: @request)
    end

    context 'when using standard authentications' do
      context 'invalid password' do
        it 'does not authenticate user' do
          post(:create, params: { user: { login: 'invalid', password: 'invalid' } })

          expect(response)
            .to set_flash.now[:alert].to /Invalid Login or password/
        end
      end

      context 'when using valid password', :clean_gitlab_redis_shared_state do
        let(:user) { create(:user) }
        let(:user_params) { { login: user.username, password: user.password } }

        it 'authenticates user correctly' do
          post(:create, params: { user: user_params })

          expect(subject.current_user).to eq user
        end

        context 'with password authentication disabled' do
          before do
            stub_application_setting(password_authentication_enabled_for_web: false)
          end

          it 'does not sign in the user' do
            post(:create, params: { user: user_params })

            expect(@request.env['warden']).not_to be_authenticated
            expect(subject.current_user).to be_nil
          end

          it 'returns status 403' do
            post(:create, params: { user: user_params })

            expect(response.status).to eq 403
          end
        end

        it 'creates an audit log record' do
          expect { post(:create, params: { user: user_params }) }.to change { SecurityEvent.count }.by(1)
          expect(SecurityEvent.last.details[:with]).to eq('standard')
        end

        include_examples 'user login request with unique ip limit', 302 do
          def request
            post(:create, params: { user: user_params })
            expect(subject.current_user).to eq user
            subject.sign_out user
          end
        end

        it 'updates the user activity' do
          expect do
            post(:create, params: { user: user_params })
          end.to change { user.reload.last_activity_on }.to(Date.today)
        end
      end

      context 'when reCAPTCHA is enabled' do
        let(:user) { create(:user) }
        let(:user_params) { { login: user.username, password: user.password } }

        before do
          stub_application_setting(recaptcha_enabled: true)
          request.headers[described_class::CAPTCHA_HEADER] = 1
        end

        it 'displays an error when the reCAPTCHA is not solved' do
          # Without this, `verify_recaptcha` arbitrarily returns true in test env
          Recaptcha.configuration.skip_verify_env.delete('test')
          counter = double(:counter)

          expect(counter).to receive(:increment)
          expect(Gitlab::Metrics).to receive(:counter)
                                      .with(:failed_login_captcha_total, anything)
                                      .and_return(counter)

          post(:create, params: { user: user_params })

          expect(response).to render_template(:new)
          expect(flash[:alert]).to include 'There was an error with the reCAPTCHA. Please solve the reCAPTCHA again.'
          expect(subject.current_user).to be_nil
        end

        it 'successfully logs in a user when reCAPTCHA is solved' do
          # Avoid test ordering issue and ensure `verify_recaptcha` returns true
          Recaptcha.configuration.skip_verify_env << 'test'
          counter = double(:counter)

          expect(counter).to receive(:increment)
          expect(Gitlab::Metrics).to receive(:counter)
                                      .with(:successful_login_captcha_total, anything)
                                      .and_return(counter)
          expect(Gitlab::Metrics).to receive(:counter).and_call_original

          post(:create, params: { user: user_params })

          expect(subject.current_user).to eq user
        end
      end
    end

    context 'when using two-factor authentication via OTP' do
      let(:user) { create(:user, :two_factor) }

      def authenticate_2fa(user_params)
        post(:create, params: { user: user_params }, session: { otp_user_id: user.id })
      end

      context 'remember_me field' do
        it 'sets a remember_user_token cookie when enabled' do
          allow(controller).to receive(:find_user).and_return(user)
          expect(controller)
            .to receive(:remember_me).with(user).and_call_original

          authenticate_2fa(remember_me: '1', otp_attempt: user.current_otp)

          expect(response.cookies['remember_user_token']).to be_present
        end

        it 'does nothing when disabled' do
          allow(controller).to receive(:find_user).and_return(user)
          expect(controller).not_to receive(:remember_me)

          authenticate_2fa(remember_me: '0', otp_attempt: user.current_otp)

          expect(response.cookies['remember_user_token']).to be_nil
        end
      end

      context 'with password authentication disabled' do
        before do
          stub_application_setting(password_authentication_enabled_for_web: false)
        end

        it 'allows 2FA stage of non-password login' do
          authenticate_2fa(otp_attempt: user.current_otp)

          expect(@request.env['warden']).to be_authenticated
          expect(subject.current_user).to eq user
        end
      end

      ##
      # See #14900 issue
      #
      context 'when authenticating with login and OTP of another user' do
        context 'when another user has 2FA enabled' do
          let(:another_user) { create(:user, :two_factor) }

          context 'when OTP is valid for another user' do
            it 'does not authenticate' do
              authenticate_2fa(login: another_user.username,
                               otp_attempt: another_user.current_otp)

              expect(subject.current_user).not_to eq another_user
            end
          end

          context 'when OTP is invalid for another user' do
            it 'does not authenticate' do
              authenticate_2fa(login: another_user.username,
                               otp_attempt: 'invalid')

              expect(subject.current_user).not_to eq another_user
            end
          end

          context 'when authenticating with OTP' do
            context 'when OTP is valid' do
              it 'authenticates correctly' do
                authenticate_2fa(otp_attempt: user.current_otp)

                expect(subject.current_user).to eq user
              end
            end

            context 'when OTP is invalid' do
              before do
                authenticate_2fa(otp_attempt: 'invalid')
              end

              it 'does not authenticate' do
                expect(subject.current_user).not_to eq user
              end

              it 'warns about invalid OTP code' do
                expect(response).to set_flash.now[:alert]
                  .to /Invalid two-factor code/
              end
            end
          end

          context 'when the user is on their last attempt' do
            before do
              user.update(failed_attempts: User.maximum_attempts.pred)
            end

            context 'when OTP is valid' do
              it 'authenticates correctly' do
                authenticate_2fa(otp_attempt: user.current_otp)

                expect(subject.current_user).to eq user
              end
            end

            context 'when OTP is invalid' do
              before do
                authenticate_2fa(otp_attempt: 'invalid')
              end

              it 'does not authenticate' do
                expect(subject.current_user).not_to eq user
              end

              it 'warns about invalid login' do
                expect(response).to set_flash.now[:alert]
                  .to /Invalid Login or password/
              end

              it 'locks the user' do
                expect(user.reload).to be_access_locked
              end

              it 'keeps the user locked on future login attempts' do
                post(:create, params: { user: { login: user.username, password: user.password } })

                expect(response)
                  .to set_flash.now[:alert].to /Invalid Login or password/
              end
            end
          end

          context 'when another user does not have 2FA enabled' do
            let(:another_user) { create(:user) }

            it 'does not leak that 2FA is disabled for another user' do
              authenticate_2fa(login: another_user.username,
                               otp_attempt: 'invalid')

              expect(response).to set_flash.now[:alert]
                .to /Invalid two-factor code/
            end
          end
        end
      end

      it "creates an audit log record" do
        expect { authenticate_2fa(login: user.username, otp_attempt: user.current_otp) }.to change { SecurityEvent.count }.by(1)
        expect(SecurityEvent.last.details[:with]).to eq("two-factor")
      end
    end

    context 'when using two-factor authentication via U2F device' do
      let(:user) { create(:user, :two_factor) }

      def authenticate_2fa_u2f(user_params)
        post(:create, params: { user: user_params }, session: { otp_user_id: user.id })
      end

      context 'remember_me field' do
        it 'sets a remember_user_token cookie when enabled' do
          allow(U2fRegistration).to receive(:authenticate).and_return(true)
          allow(controller).to receive(:find_user).and_return(user)
          expect(controller)
            .to receive(:remember_me).with(user).and_call_original

          authenticate_2fa_u2f(remember_me: '1', login: user.username, device_response: "{}")

          expect(response.cookies['remember_user_token']).to be_present
        end

        it 'does nothing when disabled' do
          allow(U2fRegistration).to receive(:authenticate).and_return(true)
          allow(controller).to receive(:find_user).and_return(user)
          expect(controller).not_to receive(:remember_me)

          authenticate_2fa_u2f(remember_me: '0', login: user.username, device_response: "{}")

          expect(response.cookies['remember_user_token']).to be_nil
        end
      end

      it "creates an audit log record" do
        allow(U2fRegistration).to receive(:authenticate).and_return(true)
        expect { authenticate_2fa_u2f(login: user.username, device_response: "{}") }.to change { SecurityEvent.count }.by(1)
        expect(SecurityEvent.last.details[:with]).to eq("two-factor-via-u2f-device")
      end
    end
  end

  describe "#new" do
    before do
      set_devise_mapping(context: @request)
    end

    it "redirects correctly for referer on same host with params" do
      host = "test.host"
      search_path = "/search?search=seed_project"
      request.headers[:HTTP_REFERER] = "http://#{host}#{search_path}"

      get(:new, params: { redirect_to_referer: :yes })

      expect(controller.stored_location_for(:redirect)).to eq(search_path)
    end
  end
end
