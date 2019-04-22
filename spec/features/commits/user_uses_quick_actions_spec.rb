# frozen_string_literal: true

require 'rails_helper'

describe 'Commit > User uses quick actions', :js do
  include Spec::Support::Helpers::Features::NotesHelpers
  include RepoHelpers

  let(:project) { create(:project, :public, :repository) }
  let(:user) { project.creator }
  let(:commit) { project.commit }

  before do
    project.add_maintainer(user)
    sign_in(user)

    visit project_commit_path(project, commit.id)
  end

  describe 'Tagging a commit' do
    let(:tag_name) { 'v1.2.3' }
    let(:tag_message) { 'Stable release' }
    let(:truncated_commit_sha) { Commit.truncate_sha(commit.sha) }

    it_behaves_like 'tag quick action'
  end
end
