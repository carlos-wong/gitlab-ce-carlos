# frozen_string_literal: true

require 'spec_helper'

describe Dashboard::SnippetsController do
  let(:user) { create(:user) }

  before do
    sign_in(user)
  end

  describe 'GET #index' do
    it_behaves_like 'paginated collection' do
      let(:collection) { Snippet.all }

      before do
        create(:personal_snippet, :public, author: user)
      end
    end

    it 'fetches snippet counts via the snippet count service' do
      service = double(:count_service, execute: {})
      expect(Snippets::CountService)
        .to receive(:new).with(user, author: user)
        .and_return(service)

      get :index
    end
  end
end
