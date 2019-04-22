require 'spec_helper'

describe 'Sessions (JavaScript fixtures)' do
  include JavaScriptFixturesHelpers

  before(:all) do
    clean_frontend_fixtures('sessions/')
  end

  describe SessionsController, '(JavaScript fixtures)', type: :controller do
    include DeviseHelpers

    render_views

    before do
      set_devise_mapping(context: @request)
    end

    it 'sessions/new.html' do |example|
      get :new

      expect(response).to be_success
      store_frontend_fixture(response, example.description)
    end
  end
end
