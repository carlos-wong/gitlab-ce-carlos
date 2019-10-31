# frozen_string_literal: true

require 'spec_helper'

describe 'projects/merge_requests/edit.html.haml' do
  include Devise::Test::ControllerHelpers
  include ProjectForksHelper

  let(:user) { create(:user) }
  let(:project) { create(:project, :repository) }
  let(:forked_project) { fork_project(project, user, repository: true) }
  let(:unlink_project) { Projects::UnlinkForkService.new(forked_project, user) }
  let(:milestone) { create(:milestone, project: project) }

  let(:closed_merge_request) do
    project.add_developer(user)

    create(:closed_merge_request,
      source_project: forked_project,
      target_project: project,
      author: user,
      assignees: [user],
      milestone: milestone)
  end

  before do
    assign(:project, project)
    assign(:target_project, project)
    assign(:merge_request, closed_merge_request)
    assign(:mr_presenter, closed_merge_request.present(current_user: user))

    allow(view).to receive(:can?).and_return(true)
    allow(view).to receive(:current_user)
      .and_return(User.find(closed_merge_request.author_id))
  end

  context 'when a merge request without fork' do
    it "shows editable fields" do
      unlink_project.execute
      closed_merge_request.reload

      render

      expect(rendered).to have_field('merge_request[title]')
      expect(rendered).to have_field('merge_request[description]')
      expect(rendered).to have_selector('input[name="merge_request[label_ids][]"]', visible: false)
      expect(rendered).to have_selector('#merge_request_milestone_id', visible: false)
      expect(rendered).not_to have_selector('#merge_request_target_branch', visible: false)
    end
  end

  context 'when a merge request with an existing source project is closed' do
    it "shows editable fields" do
      render

      expect(rendered).to have_field('merge_request[title]')
      expect(rendered).to have_field('merge_request[description]')
      expect(rendered).to have_selector('input[name="merge_request[label_ids][]"]', visible: false)
      expect(rendered).to have_selector('#merge_request_milestone_id', visible: false)
      expect(rendered).to have_selector('#merge_request_target_branch', visible: false)
    end
  end
end
