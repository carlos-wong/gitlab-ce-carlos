# frozen_string_literal: true

require 'spec_helper'

describe 'Project Issues Calendar Feed' do
  describe 'GET /issues' do
    let!(:user)     { create(:user, email: 'private1@example.com', public_email: 'public1@example.com') }
    let!(:assignee) { create(:user, email: 'private2@example.com', public_email: 'public2@example.com') }
    let!(:project)  { create(:project) }
    let!(:issue)    { create(:issue, author: user, assignees: [assignee], project: project) }

    before do
      project.add_developer(user)
    end

    context 'when authenticated' do
      context 'with no referer' do
        it 'renders calendar feed' do
          sign_in user
          visit project_issues_path(project, :ics)

          expect(response_headers['Content-Type']).to have_content('text/calendar')
          expect(body).to have_text('BEGIN:VCALENDAR')
        end
      end

      context 'with GitLab as the referer' do
        it 'renders calendar feed as text/plain' do
          sign_in user
          page.driver.header('Referer', project_issues_url(project, host: Settings.gitlab.base_url))
          visit project_issues_path(project, :ics)

          expect(response_headers['Content-Type']).to have_content('text/plain')
          expect(body).to have_text('BEGIN:VCALENDAR')
        end
      end
    end

    context 'when authenticated via personal access token' do
      it 'renders calendar feed' do
        personal_access_token = create(:personal_access_token, user: user)

        visit project_issues_path(project, :ics, private_token: personal_access_token.token)

        expect(response_headers['Content-Type']).to have_content('text/calendar')
        expect(body).to have_text('BEGIN:VCALENDAR')
      end
    end

    context 'when authenticated via feed token' do
      it 'renders calendar feed' do
        visit project_issues_path(project, :ics, feed_token: user.feed_token)

        expect(response_headers['Content-Type']).to have_content('text/calendar')
        expect(body).to have_text('BEGIN:VCALENDAR')
      end
    end

    context 'issue with due date' do
      let!(:issue) do
        create(:issue, author: user, assignees: [assignee], project: project, title: 'test title',
                       description: 'test desc', due_date: Date.tomorrow)
      end

      it 'renders issue fields' do
        visit project_issues_path(project, :ics, feed_token: user.feed_token)

        expect(body).to have_text("SUMMARY:test title (in #{project.full_path})")
        # line length for ics is 75 chars
        expected_description = (+"DESCRIPTION:Find out more at #{issue_url(issue)}").insert(75, ' ')
        expect(body).to have_text(expected_description)
        expect(body).to have_text("DTSTART;VALUE=DATE:#{Date.tomorrow.strftime('%Y%m%d')}")
        expect(body).to have_text("URL:#{issue_url(issue)}")
        expect(body).to have_text('TRANSP:TRANSPARENT')
      end
    end

    context 'sorted by priority' do
      it 'renders calendar feed' do
        visit project_issues_path(project, :ics, sort: 'priority', feed_token: user.feed_token)

        expect(response_headers['Content-Type']).to have_content('text/calendar')
        expect(body).to have_text('BEGIN:VCALENDAR')
      end
    end
  end
end
