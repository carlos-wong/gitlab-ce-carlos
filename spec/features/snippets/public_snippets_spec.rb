# frozen_string_literal: true

require 'rails_helper'

describe 'Public Snippets', :js do
  it 'Unauthenticated user should see public snippets' do
    public_snippet = create(:personal_snippet, :public)

    visit snippet_path(public_snippet)
    wait_for_requests

    expect(page).to have_content(public_snippet.content)
  end

  it 'Unauthenticated user should see raw public snippets' do
    public_snippet = create(:personal_snippet, :public)

    visit raw_snippet_path(public_snippet)

    expect(page).to have_content(public_snippet.content)
  end
end
