require 'spec_helper'

describe 'Projects > Files > User views files page' do
  let(:project) { create(:forked_project_with_submodules) }
  let(:user) { project.owner }

  before do
    stub_feature_flags(vue_file_list: false)

    sign_in user
    visit project_tree_path(project, project.repository.root_ref)
  end

  it 'user sees folders and submodules sorted together, followed by files' do
    rows = all('td.tree-item-file-name').map(&:text)
    tree = project.repository.tree

    folders = tree.trees.map(&:name)
    files = tree.blobs.map(&:name)
    submodules = tree.submodules.map do |submodule|
      submodule.name + " @ " + submodule.id[0..7]
    end

    sorted_titles = (folders + submodules).sort + files

    expect(rows).to eq(sorted_titles)
  end
end
