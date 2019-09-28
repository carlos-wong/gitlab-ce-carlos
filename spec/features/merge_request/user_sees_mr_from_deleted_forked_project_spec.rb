# frozen_string_literal: true

require 'spec_helper'

describe 'Merge request > User sees MR from deleted forked project', :js do
  include ProjectForksHelper

  let(:project) { create(:project, :public, :repository) }
  let(:user) { project.creator }
  let(:forked_project) { fork_project(project, nil, repository: true) }
  let!(:merge_request) do
    create(:merge_request_with_diffs, source_project: forked_project,
                                      target_project: project,
                                      description: 'Test merge request')
  end

  before do
    MergeRequests::MergeService.new(project, user).execute(merge_request)
    forked_project.destroy!
    sign_in(user)
    visit project_merge_request_path(project, merge_request)
  end

  it 'user can access merge request' do
    expect(page).to have_content 'Test merge request'
    expect(page).to have_content "(removed):#{merge_request.source_branch}"
  end
end
