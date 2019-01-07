require 'spec_helper'

describe API::Events do
  include ApiHelpers

  let(:user) { create(:user) }
  let(:non_member) { create(:user) }
  let(:private_project) { create(:project, :private, creator_id: user.id, namespace: user.namespace) }
  let(:closed_issue) { create(:closed_issue, project: private_project, author: user) }
  let!(:closed_issue_event) { create(:event, project: private_project, author: user, target: closed_issue, action: Event::CLOSED, created_at: Date.new(2016, 12, 30)) }

  describe 'GET /events' do
    context 'when unauthenticated' do
      it 'returns authentication error' do
        get api('/events')

        expect(response).to have_gitlab_http_status(401)
      end
    end

    context 'when authenticated' do
      it 'returns users events' do
        get api('/events?action=closed&target_type=issue&after=2016-12-1&before=2016-12-31', user)

        expect(response).to have_gitlab_http_status(200)
        expect(response).to include_pagination_headers
        expect(json_response).to be_an Array
        expect(json_response.size).to eq(1)
      end
    end

    context 'when the requesting token has "read_user" scope' do
      let(:token) { create(:personal_access_token, scopes: ['read_user'], user: user) }

      it 'returns users events' do
        get api('/events?action=closed&target_type=issue&after=2016-12-1&before=2016-12-31', personal_access_token: token)

        expect(response).to have_gitlab_http_status(200)
        expect(response).to include_pagination_headers
        expect(json_response).to be_an Array
        expect(json_response.size).to eq(1)
      end
    end

    context 'when the requesting token does not have "read_user" or "api" scope' do
      let(:token_without_scopes) { create(:personal_access_token, scopes: ['read_repository'], user: user) }

      it 'returns a "403" response' do
        get api('/events', personal_access_token: token_without_scopes)

        expect(response).to have_gitlab_http_status(403)
      end
    end
  end

  describe 'GET /users/:id/events' do
    context "as a user that cannot see another user" do
      it 'returns a "404" response' do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(non_member, :read_user, user).and_return(false)

        get api("/users/#{user.id}/events", non_member)

        expect(response).to have_gitlab_http_status(200)
        expect(json_response).to be_empty
      end
    end

    context "as a user token that cannot see another user" do
      let(:non_member_token) { create(:personal_access_token, scopes: ['read_user'], user: non_member) }

      it 'returns a "404" response' do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(non_member, :read_user, user).and_return(false)

        get api("/users/#{user.id}/events", personal_access_token: non_member_token)

        expect(response).to have_gitlab_http_status(200)
        expect(json_response).to be_empty
      end
    end

    context "as a user that can see the event's project" do
      it 'accepts a username' do
        get api("/users/#{user.username}/events", user)

        expect(response).to have_gitlab_http_status(200)
        expect(response).to include_pagination_headers
        expect(json_response).to be_an Array
        expect(json_response.size).to eq(1)
      end

      it 'returns the events' do
        get api("/users/#{user.id}/events", user)

        expect(response).to have_gitlab_http_status(200)
        expect(response).to include_pagination_headers
        expect(json_response).to be_an Array
        expect(json_response.size).to eq(1)
      end

      context 'when the list of events includes push events' do
        let(:event) do
          create(:push_event, author: user, project: private_project)
        end

        let!(:payload) { create(:push_event_payload, event: event) }
        let(:payload_hash) { json_response[0]['push_data'] }

        before do
          get api("/users/#{user.id}/events?action=pushed", user)
        end

        it 'responds with HTTP 200 OK' do
          expect(response).to have_gitlab_http_status(200)
        end

        it 'includes the push payload as a Hash' do
          expect(payload_hash).to be_an_instance_of(Hash)
        end

        it 'includes the push payload details' do
          expect(payload_hash['commit_count']).to eq(payload.commit_count)
          expect(payload_hash['action']).to eq(payload.action)
          expect(payload_hash['ref_type']).to eq(payload.ref_type)
          expect(payload_hash['commit_to']).to eq(payload.commit_to)
        end
      end

      context 'when there are multiple events from different projects' do
        let(:second_note) { create(:note_on_issue, project: create(:project)) }

        before do
          second_note.project.add_user(user, :developer)

          [second_note].each do |note|
            EventCreateService.new.leave_note(note, user)
          end
        end

        it 'returns events in the correct order (from newest to oldest)' do
          get api("/users/#{user.id}/events", user)

          comment_events = json_response.select { |e| e['action_name'] == 'commented on' }
          close_events = json_response.select { |e| e['action_name'] == 'closed' }

          expect(comment_events[0]['target_id']).to eq(second_note.id)
          expect(close_events[0]['target_id']).to eq(closed_issue.id)
        end

        it 'accepts filter parameters' do
          get api("/users/#{user.id}/events?action=closed&target_type=issue&after=2016-12-1&before=2016-12-31", user)

          expect(json_response.size).to eq(1)
          expect(json_response[0]['target_id']).to eq(closed_issue.id)
        end
      end
    end

    it 'returns a 404 error if not found' do
      get api('/users/42/events', user)

      expect(response).to have_gitlab_http_status(404)
      expect(json_response['message']).to eq('404 User Not Found')
    end
  end

  describe 'GET /projects/:id/events' do
    context 'when unauthenticated ' do
      it 'returns 404 for private project' do
        get api("/projects/#{private_project.id}/events")

        expect(response).to have_gitlab_http_status(404)
      end

      it 'returns 200 status for a public project' do
        public_project = create(:project, :public)

        get api("/projects/#{public_project.id}/events")

        expect(response).to have_gitlab_http_status(200)
      end
    end

    context 'with inaccessible events' do
      let(:public_project) { create(:project, :public, creator_id: user.id, namespace: user.namespace) }
      let(:confidential_issue) { create(:closed_issue, confidential: true, project: public_project, author: user) }
      let!(:confidential_event) { create(:event, project: public_project, author: user, target: confidential_issue, action: Event::CLOSED) }
      let(:public_issue) { create(:closed_issue, project: public_project, author: user) }
      let!(:public_event) { create(:event, project: public_project, author: user, target: public_issue, action: Event::CLOSED) }

      it 'returns only accessible events' do
        get api("/projects/#{public_project.id}/events", non_member)

        expect(response).to have_gitlab_http_status(200)
        expect(json_response.size).to eq(1)
      end

      it 'returns all events when the user has access' do
        get api("/projects/#{public_project.id}/events", user)

        expect(response).to have_gitlab_http_status(200)
        expect(json_response.size).to eq(2)
      end
    end

    context 'pagination' do
      let(:public_project) { create(:project, :public) }

      before do
        create(:event,
               project: public_project,
               target: create(:issue, project: public_project, title: 'Issue 1'),
               action: Event::CLOSED,
               created_at: Date.parse('2018-12-10'))
        create(:event,
               project: public_project,
               target: create(:issue, confidential: true, project: public_project, title: 'Confidential event'),
               action: Event::CLOSED,
               created_at: Date.parse('2018-12-11'))
        create(:event,
               project: public_project,
               target: create(:issue, project: public_project, title: 'Issue 2'),
               action: Event::CLOSED,
               created_at: Date.parse('2018-12-12'))
      end

      it 'correctly returns the second page without inaccessible events' do
        get api("/projects/#{public_project.id}/events", user), params: { per_page: 2, page: 2 }

        titles = json_response.map { |event| event['target_title'] }

        expect(titles.first).to eq('Issue 1')
        expect(titles).not_to include('Confidential event')
      end

      it 'correctly returns the first page without inaccessible events' do
        get api("/projects/#{public_project.id}/events", user), params: { per_page: 2, page: 1 }

        titles = json_response.map { |event| event['target_title'] }

        expect(titles.first).to eq('Issue 2')
        expect(titles).not_to include('Confidential event')
      end
    end

    context 'when not permitted to read' do
      it 'returns 404' do
        get api("/projects/#{private_project.id}/events", non_member)

        expect(response).to have_gitlab_http_status(404)
      end
    end

    context 'when authenticated' do
      it 'returns project events' do
        get api("/projects/#{private_project.id}/events?action=closed&target_type=issue&after=2016-12-1&before=2016-12-31", user)

        expect(response).to have_gitlab_http_status(200)
        expect(response).to include_pagination_headers
        expect(json_response).to be_an Array
        expect(json_response.size).to eq(1)
      end

      it 'returns 404 if project does not exist' do
        get api("/projects/1234/events", user)

        expect(response).to have_gitlab_http_status(404)
      end
    end

    context 'when exists some events' do
      let(:merge_request1) { create(:merge_request, :closed, author: user, assignee: user, source_project: private_project, title: 'Test') }
      let(:merge_request2) { create(:merge_request, :closed, author: user, assignee: user, source_project: private_project, title: 'Test') }

      before do
        create_event(merge_request1)
      end

      it 'avoids N+1 queries' do
        control_count = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          get api("/projects/#{private_project.id}/events", user), params: { target_type: :merge_request }
        end.count

        create_event(merge_request2)

        expect do
          get api("/projects/#{private_project.id}/events", user), params: { target_type: :merge_request }
        end.not_to exceed_all_query_limit(control_count)

        expect(response).to have_gitlab_http_status(200)
        expect(response).to include_pagination_headers
        expect(json_response.size).to eq(2)
        expect(json_response.map { |r| r['target_id'] }).to match_array([merge_request1.id, merge_request2.id])
      end

      def create_event(target)
        create(:event, project: private_project, author: user, target: target)
      end
    end
  end
end
