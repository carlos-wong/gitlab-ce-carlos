# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'File blame', :js do
  include TreeHelper

  let_it_be(:project) { create(:project, :public, :repository) }

  let(:path) { 'CHANGELOG' }

  def visit_blob_blame(path)
    visit project_blame_path(project, tree_join('master', path))
    wait_for_all_requests
  end

  it 'displays the blame page without pagination' do
    visit_blob_blame(path)

    expect(page).to have_css('.blame-commit')
    expect(page).not_to have_css('.gl-pagination')
  end

  context 'when blob length is over the blame range limit' do
    before do
      stub_const('Projects::BlameService::PER_PAGE', 2)
    end

    it 'displays two first lines of the file with pagination' do
      visit_blob_blame(path)

      expect(page).to have_css('.blame-commit')
      expect(page).to have_css('.gl-pagination')

      expect(page).to have_css('#L1')
      expect(page).not_to have_css('#L3')
      expect(find('.page-link.active')).to have_text('1')
    end

    context 'when user clicks on the next button' do
      before do
        visit_blob_blame(path)

        find('.js-next-button').click
      end

      it 'displays next two lines of the file with pagination' do
        expect(page).not_to have_css('#L1')
        expect(page).to have_css('#L3')
        expect(find('.page-link.active')).to have_text('2')
      end

      it 'correctly redirects to the prior blame page' do
        find('.version-link').click

        expect(find('.page-link.active')).to have_text('2')
      end
    end

    context 'when feature flag disabled' do
      before do
        stub_feature_flags(blame_page_pagination: false)
      end

      it 'displays the blame page without pagination' do
        visit_blob_blame(path)

        expect(page).to have_css('.blame-commit')
        expect(page).not_to have_css('.gl-pagination')
      end
    end
  end

  context 'when blob length is over global max page limit' do
    before do
      stub_const('Projects::BlameService::PER_PAGE', 200)
    end

    let(:path) { 'files/markdown/ruby-style-guide.md' }

    it 'displays two hundred lines of the file with pagination' do
      visit_blob_blame(path)

      expect(page).to have_css('.blame-commit')
      expect(page).to have_css('.gl-pagination')

      expect(page).to have_css('#L1')
      expect(page).not_to have_css('#L201')
      expect(find('.page-link.active')).to have_text('1')
    end

    context 'when user clicks on the next button' do
      before do
        visit_blob_blame(path)

        find('.js-next-button').click
      end

      it 'displays next two hundred lines of the file with pagination' do
        expect(page).not_to have_css('#L1')
        expect(page).to have_css('#L201')
        expect(find('.page-link.active')).to have_text('2')
      end
    end
  end
end
