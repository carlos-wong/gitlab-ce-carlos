# frozen_string_literal: true

require 'rails_helper'

describe 'List issue resource label events', :js do
  let(:user)     { create(:user) }
  let(:project)  { create(:project, :public) }
  let(:issue)    { create(:issue, project: project, author: user) }
  let!(:label) { create(:label, project: project, title: 'foo') }
  let!(:user_status) { create(:user_status, user: user) }

  context 'when user displays the issue' do
    let!(:note)     { create(:note_on_issue, author: user, project: project, noteable: issue, note: 'some note') }
    let!(:event)    { create(:resource_label_event, user: user, issue: issue, label: label) }

    before do
      visit project_issue_path(project, issue)
      wait_for_requests
    end

    it 'shows both notes and resource label events' do
      page.within('#notes') do
        expect(find("#note_#{note.id}")).to have_content 'some note'
        expect(find("#note_#{event.discussion_id}")).to have_content 'added foo label'
      end
    end

    it 'shows the user status on the system note for the label' do
      page.within("#note_#{event.discussion_id}") do
        expect(page).to show_user_status user_status
      end
    end
  end

  context 'when user adds label to the issue' do
    def toggle_labels(labels)
      page.within '.labels' do
        click_link 'Edit'
        wait_for_requests

        labels.each { |label| click_link label }

        click_link 'Edit'
        wait_for_requests
      end
    end

    before do
      create(:label, project: project, title: 'bar')
      project.add_developer(user)

      sign_in(user)
      visit project_issue_path(project, issue)
      wait_for_requests
    end

    it 'shows add note for newly added labels' do
      toggle_labels(%w(foo bar))
      visit project_issue_path(project, issue)
      wait_for_requests

      page.within('#notes') do
        expect(page).to have_content 'added bar foo labels'
      end
    end
  end
end
