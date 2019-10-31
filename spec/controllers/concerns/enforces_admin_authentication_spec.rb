# frozen_string_literal: true

require 'spec_helper'

describe EnforcesAdminAuthentication, :do_not_mock_admin_mode do
  include AdminModeHelper

  let(:user) { create(:user) }

  before do
    sign_in(user)
  end

  controller(ApplicationController) do
    include EnforcesAdminAuthentication

    def index
      head :ok
    end
  end

  context 'feature flag :user_mode_in_session is enabled' do
    describe 'authenticate_admin!' do
      context 'as an admin' do
        let(:user) { create(:admin) }

        it 'renders redirect for re-authentication and does not set admin mode' do
          get :index

          expect(response).to redirect_to new_admin_session_path
          expect(assigns(:current_user_mode)&.admin_mode?).to be(false)
        end

        context 'when admin mode is active' do
          before do
            enable_admin_mode!(user)
          end

          it 'renders ok' do
            get :index

            expect(response).to have_gitlab_http_status(200)
          end
        end
      end

      context 'as a user' do
        it 'renders a 404' do
          get :index

          expect(response).to have_gitlab_http_status(404)
        end

        it 'does not set admin mode' do
          get :index

          # check for nil too since on 404, current_user_mode might not be initialized
          expect(assigns(:current_user_mode)&.admin_mode?).to be_falsey
        end
      end
    end
  end

  context 'feature flag :user_mode_in_session is disabled' do
    before do
      stub_feature_flags(user_mode_in_session: false)
    end

    describe 'authenticate_admin!' do
      before do
        get :index
      end

      context 'as an admin' do
        let(:user) { create(:admin) }

        it 'allows direct access to page' do
          expect(response).to have_gitlab_http_status(200)
        end

        it 'does not set admin mode' do
          expect(assigns(:current_user_mode)&.admin_mode?).to be_falsey
        end
      end

      context 'as a user' do
        it 'renders a 404' do
          expect(response).to have_gitlab_http_status(404)
        end

        it 'does not set admin mode' do
          # check for nil too since on 404, current_user_mode might not be initialized
          expect(assigns(:current_user_mode)&.admin_mode?).to be_falsey
        end
      end
    end
  end
end
