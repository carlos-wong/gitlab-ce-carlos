# frozen_string_literal: true

require 'spec_helper'

describe 'User searches for commits' do
  let(:project) { create(:project, :repository) }
  let(:sha) { '6d394385cf567f80a8fd85055db1ab4c5295806f' }
  let(:user) { create(:user) }

  before do
    project.add_reporter(user)
    sign_in(user)

    visit(search_path(project_id: project.id))
  end

  context 'when searching by SHA' do
    it 'finds a commit and redirects to its page' do
      submit_search(sha)

      expect(page).to have_current_path(project_commit_path(project, sha))
    end

    it 'finds a commit in uppercase and redirects to its page' do
      submit_search(sha.upcase)

      expect(page).to have_current_path(project_commit_path(project, sha))
    end
  end

  context 'when searching by message' do
    it 'finds a commit and holds on /search page' do
      create_commit('Message referencing another sha: "deadbeef"', project, user, 'master')

      submit_search('deadbeef')

      expect(page).to have_current_path('/search', ignore_query: true)
    end

    it 'finds multiple commits' do
      submit_search('See merge request')
      select_search_scope('Commits')

      expect(page).to have_selector('.commit-row-description', count: 9)
    end
  end
end
