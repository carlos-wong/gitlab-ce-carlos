# frozen_string_literal: true

require 'spec_helper'

describe 'Project Commits RSS' do
  let(:user) { create(:user) }
  let(:project) { create(:project, :repository, visibility_level: Gitlab::VisibilityLevel::PUBLIC) }
  let(:path) { project_commits_path(project, :master) }

  context 'when signed in' do
    before do
      project.add_developer(user)
      sign_in(user)
      visit path
    end

    it_behaves_like "it has an RSS button with current_user's feed token"
    it_behaves_like "an autodiscoverable RSS feed with current_user's feed token"
  end

  context 'when signed out' do
    before do
      visit path
    end

    it_behaves_like "it has an RSS button without a feed token"
    it_behaves_like "an autodiscoverable RSS feed without a feed token"
  end
end
