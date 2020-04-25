# frozen_string_literal: true

require 'spec_helper'

describe Import::GiteaController do
  include ImportSpecHelper

  let(:provider) { :gitea }
  let(:host_url) { 'https://try.gitea.io' }

  include_context 'a GitHub-ish import controller'

  def assign_host_url
    session[:gitea_host_url] = host_url
  end

  describe "GET new" do
    it_behaves_like 'a GitHub-ish import controller: GET new' do
      before do
        assign_host_url
      end
    end
  end

  describe "POST personal_access_token" do
    it_behaves_like 'a GitHub-ish import controller: POST personal_access_token'
  end

  describe "GET status" do
    it_behaves_like 'a GitHub-ish import controller: GET status' do
      before do
        assign_host_url
      end
      let(:extra_assign_expectations) { { gitea_host_url: host_url } }
    end
  end

  describe 'POST create' do
    it_behaves_like 'a GitHub-ish import controller: POST create' do
      before do
        assign_host_url
      end
    end

    it_behaves_like 'project import rate limiter'
  end

  describe "GET realtime_changes" do
    it_behaves_like 'a GitHub-ish import controller: GET realtime_changes' do
      before do
        assign_host_url
      end
    end
  end
end
