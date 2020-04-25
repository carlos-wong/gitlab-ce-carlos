# frozen_string_literal: true

require 'spec_helper'

describe Admin::SpamLogsController do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }
  let!(:first_spam) { create(:spam_log, user: user) }
  let!(:second_spam) { create(:spam_log, user: user) }

  before do
    sign_in(admin)
  end

  describe '#index' do
    it 'lists all spam logs' do
      get :index

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  describe '#destroy' do
    it 'removes only the spam log when removing log' do
      expect { delete :destroy, params: { id: first_spam.id } }.to change { SpamLog.count }.by(-1)
      expect(User.find(user.id)).to be_truthy
      expect(response).to have_gitlab_http_status(:ok)
    end

    it 'removes user and their spam logs when removing the user', :sidekiq_might_not_need_inline do
      delete :destroy, params: { id: first_spam.id, remove_user: true }

      expect(flash[:notice]).to eq "User #{user.username} was successfully removed."
      expect(response).to have_gitlab_http_status(:found)
      expect(SpamLog.count).to eq(0)
      expect { User.find(user.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '#mark_as_ham' do
    before do
      allow_next_instance_of(Spam::AkismetService) do |instance|
        allow(instance).to receive(:submit_ham).and_return(true)
      end
    end
    it 'submits the log as ham' do
      post :mark_as_ham, params: { id: first_spam.id }

      expect(response).to have_gitlab_http_status(:found)
      expect(SpamLog.find(first_spam.id).submitted_as_ham).to be_truthy
    end
  end
end
