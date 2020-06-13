# frozen_string_literal: true

require 'spec_helper'

describe API::APIGuard::AdminModeMiddleware, :do_not_mock_admin_mode, :request_store do
  let(:user) { create(:admin) }

  it 'is loaded' do
    expect(API::API.middleware).to include([:use, described_class])
  end

  context 'when there is an exception in the api call' do
    let(:app) do
      Class.new(API::API) do
        get 'willfail' do
          raise StandardError.new('oh noes!')
        end
      end
    end

    it 'resets admin mode' do
      Gitlab::Auth::CurrentUserMode.bypass_session!(user.id)

      expect(Gitlab::Auth::CurrentUserMode.bypass_session_admin_id).to be(user.id)
      expect(Gitlab::Auth::CurrentUserMode).to receive(:reset_bypass_session!).and_call_original

      get api('/willfail')

      expect(response.status).to eq(500)
      expect(response.body).to include('oh noes!')

      expect(Gitlab::Auth::CurrentUserMode.bypass_session_admin_id).to be_nil
    end
  end
end
