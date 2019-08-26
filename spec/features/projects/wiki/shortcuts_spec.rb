# frozen_string_literal: true

require 'spec_helper'

describe 'Wiki shortcuts', :js do
  let(:user) { create(:user) }
  let(:project) { create(:project, :wiki_repo, namespace: user.namespace) }
  let(:wiki_page) { create(:wiki_page, wiki: project.wiki, attrs: { title: 'home', content: 'Home page' }) }

  before do
    sign_in(user)
    visit project_wiki_path(project, wiki_page)
  end

  it 'Visit edit wiki page using "e" keyboard shortcut' do
    find('body').native.send_key('e')

    expect(find('.wiki-page-title')).to have_content('Edit Page')
  end
end
