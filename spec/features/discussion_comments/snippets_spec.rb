# frozen_string_literal: true

require 'spec_helper'

describe 'Thread Comments Snippet', :js do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:snippet) { create(:project_snippet, :private, :repository, project: project, author: user) }

  before do
    stub_feature_flags(snippets_vue: false)
    project.add_maintainer(user)
    sign_in(user)

    visit project_snippet_path(project, snippet)
  end

  it_behaves_like 'thread comments', 'snippet'
end
