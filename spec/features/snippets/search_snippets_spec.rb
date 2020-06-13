# frozen_string_literal: true

require 'spec_helper'

describe 'Search Snippets' do
  it 'User searches for snippets by title' do
    public_snippet = create(:personal_snippet, :public, title: 'Beginning and Middle')
    private_snippet = create(:personal_snippet, :private, title: 'Middle and End')

    sign_in private_snippet.author
    visit dashboard_snippets_path

    submit_search('Middle')
    select_search_scope('Titles and Filenames')

    expect(page).to have_link(public_snippet.title)
    expect(page).to have_link(private_snippet.title)
  end
end
