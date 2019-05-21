require 'spec_helper'

describe 'projects/merge_requests/show.html.haml' do
  include Devise::Test::ControllerHelpers
  include ProjectForksHelper

  let(:user) { create(:user) }
  let(:project) { create(:project, :public, :repository) }
  let(:forked_project) { fork_project(project, user, repository: true) }
  let(:unlink_project) { Projects::UnlinkForkService.new(forked_project, user) }
  let(:note) { create(:note_on_merge_request, project: project, noteable: closed_merge_request) }

  let(:closed_merge_request) do
    create(:closed_merge_request,
      source_project: forked_project,
      target_project: project,
      author: user)
  end

  def preload_view_requirements
    # This will load the status fields of the author of the note and merge request
    # to avoid queries in when rendering the view being tested.
    closed_merge_request.author.status
    note.author.status
  end

  before do
    assign(:project, project)
    assign(:merge_request, closed_merge_request)
    assign(:commits_count, 0)
    assign(:note, note)
    assign(:noteable, closed_merge_request)
    assign(:notes, [])
    assign(:pipelines, Ci::Pipeline.none)
    assign(:issuable_sidebar, serialize_issuable_sidebar(user, project, closed_merge_request))

    preload_view_requirements

    allow(view).to receive_messages(current_user: user,
                                    can?: true,
                                    current_application_settings: Gitlab::CurrentSettings.current_application_settings)
  end

  describe 'merge request assignee sidebar' do
    context 'when assignee is allowed to merge' do
      it 'does not show a warning icon' do
        closed_merge_request.update(assignee_id: user.id)
        project.add_maintainer(user)
        assign(:issuable_sidebar, serialize_issuable_sidebar(user, project, closed_merge_request))

        render

        expect(rendered).not_to have_css('.cannot-be-merged')
      end
    end
  end

  context 'when the merge request is closed' do
    it 'shows the "Reopen" button' do
      render

      expect(rendered).to have_css('a', visible: true, text: 'Reopen')
      expect(rendered).to have_css('a', visible: false, text: 'Close')
    end

    it 'does not show the "Reopen" button when the source project does not exist' do
      unlink_project.execute
      closed_merge_request.reload
      preload_view_requirements

      render

      expect(rendered).to have_css('a', visible: false, text: 'Reopen')
      expect(rendered).to have_css('a', visible: false, text: 'Close')
    end
  end

  context 'when the merge request is open' do
    it 'closes the merge request if the source project does not exist' do
      closed_merge_request.update(state: 'open')
      forked_project.destroy
      # Reload merge request so MergeRequest#source_project turns to `nil`
      closed_merge_request.reload
      preload_view_requirements

      render

      expect(closed_merge_request.reload.state).to eq('closed')
      expect(rendered).to have_css('a', visible: false, text: 'Reopen')
      expect(rendered).to have_css('a', visible: false, text: 'Close')
    end
  end

  def serialize_issuable_sidebar(user, project, merge_request)
    MergeRequestSerializer
      .new(current_user: user, project: project)
      .represent(closed_merge_request, serializer: 'sidebar')
  end
end
