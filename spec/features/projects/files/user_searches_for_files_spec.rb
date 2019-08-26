# frozen_string_literal: true

require 'spec_helper'

describe 'Projects > Files > User searches for files' do
  let(:user) { project.owner }

  before do
    sign_in(user)
  end

  describe 'project main screen' do
    context 'when project is empty' do
      let(:project) { create(:project) }

      before do
        visit project_path(project)
      end

      it 'does not show any result' do
        fill_in('search', with: 'coffee')
        click_button('Go')

        expect(page).to have_content("We couldn't find any")
      end
    end

    context 'when project is not empty' do
      let(:project) { create(:project, :repository) }

      before do
        project.add_developer(user)
        visit project_path(project)
      end

      it 'shows "Find file" button' do
        expect(page).to have_selector('.tree-controls .shortcuts-find-file')
      end
    end
  end

  describe 'project tree screen' do
    let(:project) { create(:project, :repository) }

    before do
      project.add_developer(user)
      visit project_tree_path(project, project.default_branch)
    end

    it 'shows found files' do
      expect(page).to have_selector('.tree-controls .shortcuts-find-file')

      fill_in('search', with: 'coffee')
      click_button('Go')

      expect(page).to have_content('coffee')
      expect(page).to have_content('CONTRIBUTING.md')
    end
  end
end
