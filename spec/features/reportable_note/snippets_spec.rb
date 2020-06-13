# frozen_string_literal: true

require 'spec_helper'

describe 'Reportable note on snippets', :js do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }

  before do
    stub_feature_flags(snippets_vue: false)
    project.add_maintainer(user)
    sign_in(user)
  end

  describe 'on project snippet' do
    let_it_be(:snippet) { create(:project_snippet, :public, :repository, project: project, author: user) }
    let_it_be(:note) { create(:note_on_project_snippet, noteable: snippet, project: project) }

    before do
      visit project_snippet_path(project, snippet)
    end

    it_behaves_like 'reportable note', 'snippet'
  end
end
