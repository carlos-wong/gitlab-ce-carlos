# frozen_string_literal: true

require 'spec_helper'

# Test an operation that triggers background jobs requiring administrative rights
describe 'Admin mode for workers', :do_not_mock_admin_mode, :request_store, :clean_gitlab_redis_shared_state do
  let(:user) { create(:user) }
  let(:user_to_delete) { create(:user) }

  before do
    add_sidekiq_middleware

    sign_in(user)
  end

  context 'as a regular user' do
    it 'cannot delete user' do
      visit admin_user_path(user_to_delete)

      expect(page).to have_gitlab_http_status(:not_found)
    end
  end

  context 'as an admin user' do
    let(:user) { create(:admin) }

    context 'when admin mode disabled' do
      it 'cannot delete user', :js do
        visit admin_user_path(user_to_delete)

        expect(page).to have_content('Re-authentication required')
      end
    end

    context 'when admin mode enabled', :delete do
      before do
        gitlab_enable_admin_mode_sign_in(user)
      end

      it 'can delete user', :js do
        visit admin_user_path(user_to_delete)
        click_button 'Delete user'

        page.within '.modal-dialog' do
          find("input[name='username']").send_keys(user_to_delete.name)
          click_button 'Delete user'

          wait_for_requests
        end

        expect(page).to have_content('The user is being deleted.')

        # Perform jobs while logged out so that admin mode is only enabled in job metadata
        execute_jobs_signed_out(user)

        visit admin_user_path(user_to_delete)

        expect(page).to have_title('Not Found')
      end
    end
  end

  def add_sidekiq_middleware
    Sidekiq::Testing.server_middleware do |chain|
      chain.add Gitlab::SidekiqMiddleware::AdminMode::Server
    end
  end

  def execute_jobs_signed_out(user)
    gitlab_sign_out

    Sidekiq::Worker.drain_all

    sign_in(user)
    gitlab_enable_admin_mode_sign_in(user)
  end
end
