# frozen_string_literal: true

require 'rails_helper'

describe 'Internal Snippets', :js do
  let(:internal_snippet) { create(:personal_snippet, :internal) }

  describe 'normal user' do
    before do
      sign_in(create(:user))
    end

    it 'sees internal snippets' do
      visit snippet_path(internal_snippet)

      expect(page).to have_content(internal_snippet.content)
    end

    it 'sees raw internal snippets' do
      visit raw_snippet_path(internal_snippet)

      expect(page).to have_content(internal_snippet.content)
    end
  end
end
