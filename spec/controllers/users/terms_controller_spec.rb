# frozen_string_literal: true

require 'spec_helper'

describe Users::TermsController do
  include TermsHelper
  let(:user) { create(:user) }
  let(:term) { create(:term) }

  before do
    sign_in user
  end

  describe 'GET #index' do
    it 'redirects when no terms exist' do
      get :index

      expect(response).to have_gitlab_http_status(:redirect)
    end

    context 'when terms exist' do
      before do
        stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
        term
      end

      it 'shows terms when they exist' do
        get :index

        expect(response).to have_gitlab_http_status(:success)
      end

      it 'shows a message when the user already accepted the terms' do
        accept_terms(user)

        get :index

        expect(controller).to set_flash.now[:notice].to(/already accepted/)
      end
    end
  end

  describe 'POST #accept' do
    it 'saves that the user accepted the terms' do
      post :accept, params: { id: term.id }

      agreement = user.term_agreements.find_by(term: term)

      expect(agreement.accepted).to eq(true)
    end

    it 'redirects to a path when specified' do
      post :accept, params: { id: term.id, redirect: groups_path }

      expect(response).to redirect_to(groups_path)
    end

    it 'redirects to the referer when no redirect specified' do
      request.env["HTTP_REFERER"] = groups_url

      post :accept, params: { id: term.id }

      expect(response).to redirect_to(groups_path)
    end

    context 'redirecting to another domain' do
      it 'is prevented when passing a redirect param' do
        post :accept, params: { id: term.id, redirect: '//example.com/random/path' }

        expect(response).to redirect_to(root_path)
      end

      it 'is prevented when redirecting to the referer' do
        request.env["HTTP_REFERER"] = 'http://example.com/and/a/path'

        post :accept, params: { id: term.id }

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'POST #decline' do
    it 'stores that the user declined the terms' do
      post :decline, params: { id: term.id }

      agreement = user.term_agreements.find_by(term: term)

      expect(agreement.accepted).to eq(false)
    end

    it 'signs out the user' do
      post :decline, params: { id: term.id }

      expect(response).to redirect_to(root_path)
      expect(assigns(:current_user)).to be_nil
    end
  end
end
