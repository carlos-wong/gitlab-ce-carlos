# frozen_string_literal: true

require 'spec_helper'

describe 'User searches for code' do
  let(:user) { create(:user) }
  let(:project) { create(:project, :repository, namespace: user.namespace) }

  def submit_search(search, with_send_keys: false)
    page.within('.search') do
      field = find_field('search')
      field.fill_in(with: search)

      if with_send_keys
        field.send_keys(:enter)
      else
        click_button("Go")
      end
    end

    click_link('Code')
  end

  context 'when signed in' do
    before do
      project.add_maintainer(user)
      sign_in(user)
    end

    it 'finds a file' do
      visit(project_path(project))

      submit_search('application.js')

      expect(page).to have_selector('.file-content .code')
      expect(page).to have_selector("span.line[lang='javascript']")
    end

    context 'when on a project page', :js do
      before do
        visit(search_path)
      end

      include_examples 'top right search form'

      it 'finds code' do
        find('.js-search-project-dropdown').click

        page.within('.project-filter') do
          click_link(project.full_name)
        end

        fill_in('dashboard_search', with: 'rspec')
        find('.btn-search').click

        page.within('.results') do
          expect(find(:css, '.search-results')).to have_content('Update capybara, rspec-rails, poltergeist to recent versions')
        end
      end
    end

    context 'search code within refs', :js do
      let(:ref_name) { 'v1.0.0' }

      before do
        visit(project_tree_path(project, ref_name))
        submit_search('gitlab-grack', with_send_keys: true)
      end

      it 'shows ref switcher in code result summary' do
        expect(find('.js-project-refs-dropdown')).to have_text(ref_name)
      end
      it 'persists branch name across search' do
        find('.btn-search').click
        expect(find('.js-project-refs-dropdown')).to have_text(ref_name)
      end

      #  this example is use to test the desgine that the refs is not
      #  only repersent the branch as well as the tags.
      it 'ref swither list all the branchs and tags' do
        find('.js-project-refs-dropdown').click
        expect(find('.dropdown-page-one .dropdown-content')).to have_link('sha-starting-with-large-number')
        expect(find('.dropdown-page-one .dropdown-content')).to have_link('v1.0.0')
      end

      it 'search result changes when refs switched' do
        expect(find('.search-results')).not_to have_content('path = gitlab-grack')
        find('.js-project-refs-dropdown').click
        find('.dropdown-page-one .dropdown-content').click_link('master')
        expect(find('.search-results')).to have_content('path = gitlab-grack')
      end
    end

    it 'no ref switcher shown in issue result summary', :js do
      issue = create(:issue, title: 'test', project: project)
      visit(project_tree_path(project))
      submit_search('test', with_send_keys: true)
      expect(page).to have_selector('.js-project-refs-dropdown')
      page.within('.search-filter') do
        click_link('Issues')
      end
      expect(find(:css, '.search-results')).to have_link(issue.title)
      expect(page).not_to have_selector('.js-project-refs-dropdown')
    end
  end

  context 'when signed out' do
    let(:project) { create(:project, :public, :repository) }

    before do
      visit(project_path(project))
    end

    it 'finds code' do
      submit_search('rspec')

      page.within('.results') do
        expect(find(:css, '.search-results')).to have_content('Update capybara, rspec-rails, poltergeist to recent versions')
      end
    end
  end
end
