# frozen_string_literal: true

require 'spec_helper'

describe 'User explores projects' do
  set(:archived_project) { create(:project, :archived) }
  set(:internal_project) { create(:project, :internal) }
  set(:private_project) { create(:project, :private) }
  set(:public_project) { create(:project, :public) }

  context 'when not signed in' do
    context 'when viewing public projects' do
      before do
        visit(explore_projects_path)
      end

      include_examples 'shows public projects'
    end
  end

  context 'when signed in' do
    set(:user) { create(:user) }

    before do
      sign_in(user)
    end

    context 'when viewing public projects' do
      before do
        visit(explore_projects_path)
      end

      include_examples 'shows public and internal projects'
    end

    context 'when viewing most starred projects' do
      before do
        visit(starred_explore_projects_path)
      end

      include_examples 'shows public and internal projects'
    end

    context 'when viewing trending projects' do
      before do
        [archived_project, public_project].each { |project| create(:note_on_issue, project: project) }

        TrendingProject.refresh!

        visit(trending_explore_projects_path)
      end

      include_examples 'shows public projects'
    end
  end
end
