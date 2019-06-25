require 'spec_helper'

describe 'Projects > Files > User uploads files' do
  include DropzoneHelper

  let(:fork_message) do
    "You're not allowed to make changes to this project directly. "\
    "A fork of this project has been created that you can make changes in, so you can submit a merge request."
  end
  let(:user) { create(:user) }
  let(:project) { create(:project, :repository, name: 'Shop', creator: user) }
  let(:project2) { create(:project, :repository, name: 'Another Project', path: 'another-project') }
  let(:project_tree_path_root_ref) { project_tree_path(project, project.repository.root_ref) }
  let(:project2_tree_path_root_ref) { project_tree_path(project2, project2.repository.root_ref) }

  before do
    stub_feature_flags(vue_file_list: false)

    project.add_maintainer(user)
    sign_in(user)
  end

  context 'when an user has write access' do
    before do
      visit(project_tree_path_root_ref)
    end

    it 'uploads and commit a new text file', :js do
      find('.add-to-tree').click
      click_link('Upload file')
      drop_in_dropzone(File.join(Rails.root, 'spec', 'fixtures', 'doc_sample.txt'))

      page.within('#modal-upload-blob') do
        fill_in(:commit_message, with: 'New commit message')
      end

      fill_in(:branch_name, with: 'new_branch_name', visible: true)
      click_button('Upload file')

      expect(page).to have_content('New commit message')
      expect(current_path).to eq(project_new_merge_request_path(project))

      click_link('Changes')
      find("a[data-action='diffs']", text: 'Changes').click

      wait_for_requests

      expect(page).to have_content('Lorem ipsum dolor sit amet')
      expect(page).to have_content('Sed ut perspiciatis unde omnis')
    end

    it 'uploads and commit a new image file', :js do
      find('.add-to-tree').click
      click_link('Upload file')
      drop_in_dropzone(File.join(Rails.root, 'spec', 'fixtures', 'logo_sample.svg'))

      page.within('#modal-upload-blob') do
        fill_in(:commit_message, with: 'New commit message')
        fill_in(:branch_name, with: 'new_branch_name', visible: true)
        click_button('Upload file')
      end

      wait_for_all_requests

      visit(project_blob_path(project, 'new_branch_name/logo_sample.svg'))

      expect(page).to have_css('.file-content img')
    end
  end

  context 'when an user does not have write access' do
    before do
      project2.add_reporter(user)
      visit(project2_tree_path_root_ref)
    end

    it 'uploads and commit a new file to a forked project', :js do
      find('.add-to-tree').click
      click_link('Upload file')

      expect(page).to have_content(fork_message)

      find('.add-to-tree').click
      click_link('Upload file')
      drop_in_dropzone(File.join(Rails.root, 'spec', 'fixtures', 'doc_sample.txt'))

      page.within('#modal-upload-blob') do
        fill_in(:commit_message, with: 'New commit message')
      end

      click_button('Upload file')

      expect(page).to have_content('New commit message')

      fork = user.fork_of(project2.reload)

      expect(current_path).to eq(project_new_merge_request_path(fork))

      find("a[data-action='diffs']", text: 'Changes').click

      wait_for_requests

      expect(page).to have_content('Lorem ipsum dolor sit amet')
      expect(page).to have_content('Sed ut perspiciatis unde omnis')
    end
  end
end
