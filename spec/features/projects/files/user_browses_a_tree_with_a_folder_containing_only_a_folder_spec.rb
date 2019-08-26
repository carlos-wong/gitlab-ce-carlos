# frozen_string_literal: true

require 'spec_helper'

# This is a regression test for https://gitlab.com/gitlab-org/gitlab-ce/issues/37569
describe 'Projects > Files > User browses a tree with a folder containing only a folder', :js do
  let(:project) { create(:project, :empty_repo) }
  let(:user) { project.owner }

  before do
    project.repository.create_dir(user, 'foo/bar', branch_name: 'master', message: 'Add the foo/bar folder')
    sign_in(user)
    visit(project_tree_path(project, project.repository.root_ref))
    wait_for_requests
  end

  it 'shows the nested folder on a single row' do
    expect(page).to have_content('foo/bar')
  end
end
