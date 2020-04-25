# frozen_string_literal: true

require "spec_helper"

describe API::MergeRequests do
  include ProjectForksHelper

  let(:base_time)   { Time.now }
  let_it_be(:user)  { create(:user) }
  let_it_be(:user2) { create(:user) }
  let_it_be(:admin) { create(:user, :admin) }
  let(:project)     { create(:project, :public, :repository, creator: user, namespace: user.namespace, only_allow_merge_if_pipeline_succeeds: false) }
  let(:milestone)   { create(:milestone, title: '1.0.0', project: project) }
  let(:milestone1)  { create(:milestone, title: '0.9', project: project) }
  let(:merge_request_context_commit) {create(:merge_request_context_commit, message: 'test')}
  let!(:merge_request) { create(:merge_request, :simple, milestone: milestone1, author: user, assignees: [user], merge_request_context_commits: [merge_request_context_commit], source_project: project, target_project: project, source_branch: 'markdown', title: "Test", created_at: base_time) }
  let!(:merge_request_closed) { create(:merge_request, state: "closed", milestone: milestone1, author: user, assignees: [user], source_project: project, target_project: project, title: "Closed test", created_at: base_time + 1.second) }
  let!(:merge_request_merged) { create(:merge_request, state: "merged", author: user, assignees: [user], source_project: project, target_project: project, title: "Merged test", created_at: base_time + 2.seconds, merge_commit_sha: '9999999999999999999999999999999999999999') }
  let!(:merge_request_locked) { create(:merge_request, state: "locked", milestone: milestone1, author: user, assignees: [user], source_project: project, target_project: project, title: "Locked test", created_at: base_time + 1.second) }
  let!(:note)       { create(:note_on_merge_request, author: user, project: project, noteable: merge_request, note: "a comment on a MR") }
  let!(:note2)      { create(:note_on_merge_request, author: user, project: project, noteable: merge_request, note: "another comment on a MR") }
  let(:label) { create(:label, title: 'label', color: '#FFAABB', project: project) }
  let(:label2) { create(:label, title: 'a-test', color: '#FFFFFF', project: project) }

  before do
    project.add_reporter(user)
    project.add_reporter(user2)

    stub_licensed_features(multiple_merge_request_assignees: false)
  end

  shared_context 'with labels' do
    before do
      create(:label_link, label: label, target: merge_request)
      create(:label_link, label: label2, target: merge_request)
    end
  end

  shared_examples 'merge requests list' do
    context 'when unauthenticated' do
      it 'returns merge requests for public projects' do
        get api(endpoint_path)

        expect_successful_response_with_paginated_array
      end
    end

    context 'when authenticated' do
      it 'avoids N+1 queries' do
        control = ActiveRecord::QueryRecorder.new do
          get api(endpoint_path, user)
        end

        create(:merge_request, state: 'closed', milestone: milestone1, author: user, assignees: [user], source_project: project, target_project: project, title: 'Test', created_at: base_time)

        merge_request = create(:merge_request, milestone: milestone1, author: user, assignees: [user], source_project: project, target_project: project, title: 'Test', created_at: base_time)

        merge_request.metrics.update!(merged_by: user,
                                      latest_closed_by: user,
                                      latest_closed_at: 1.hour.ago,
                                      merged_at: 2.hours.ago)

        expect do
          get api(endpoint_path, user)
        end.not_to exceed_query_limit(control)
      end

      context 'when merge request is unchecked' do
        before do
          merge_request.mark_as_unchecked!
        end

        it 'checks mergeability asynchronously' do
          expect_next_instance_of(MergeRequests::MergeabilityCheckService) do |service|
            expect(service).not_to receive(:execute)
            expect(service).to receive(:async_execute)
          end

          get api(endpoint_path, user)
        end
      end

      context 'with labels' do
        include_context 'with labels'

        it 'returns an array of all merge_requests' do
          get api(endpoint_path, user)

          expect_paginated_array_response([
            merge_request_merged.id, merge_request_locked.id,
            merge_request_closed.id, merge_request.id
          ])

          expect(json_response.last['title']).to eq(merge_request.title)
          expect(json_response.last).to have_key('web_url')
          expect(json_response.last['sha']).to eq(merge_request.diff_head_sha)
          expect(json_response.last['merge_commit_sha']).to be_nil
          expect(json_response.last['merge_commit_sha']).to eq(merge_request.merge_commit_sha)
          expect(json_response.last['downvotes']).to eq(0)
          expect(json_response.last['upvotes']).to eq(0)
          expect(json_response.last['labels']).to eq([label2.title, label.title])
          expect(json_response.first['title']).to eq(merge_request_merged.title)
          expect(json_response.first['sha']).to eq(merge_request_merged.diff_head_sha)
          expect(json_response.first['merge_commit_sha']).not_to be_nil
          expect(json_response.first['merge_commit_sha']).to eq(merge_request_merged.merge_commit_sha)
        end

        context 'with labels_details' do
          it 'returns labels with details' do
            path = endpoint_path + "?with_labels_details=true"

            get api(path, user)

            expect_successful_response_with_paginated_array
            expect(json_response.last['labels'].pluck('name')).to eq([label2.title, label.title])
            expect(json_response.last['labels'].first).to match_schema('/public_api/v4/label_basic')
          end

          it 'avoids N+1 queries' do
            path = endpoint_path + "?with_labels_details=true"

            control = ActiveRecord::QueryRecorder.new do
              get api(path, user)
            end.count

            mr = create(:merge_request)
            create(:label_link, label: label, target: mr)
            create(:label_link, label: label2, target: mr)

            expect do
              get api(path, user)
            end.not_to exceed_query_limit(control)
          end
        end
      end

      it 'returns an array of all merge_requests using simple mode' do
        path = endpoint_path + '?view=simple'

        get api(path, user)

        expect_paginated_array_response([
          merge_request_merged.id, merge_request_locked.id,
          merge_request_closed.id, merge_request.id
        ])
        expect(json_response.last.keys).to match_array(%w(id iid title web_url created_at description project_id state updated_at))
        expect(json_response.last['iid']).to eq(merge_request.iid)
        expect(json_response.last['title']).to eq(merge_request.title)
        expect(json_response.last).to have_key('web_url')
        expect(json_response.first['iid']).to eq(merge_request_merged.iid)
        expect(json_response.first['title']).to eq(merge_request_merged.title)
        expect(json_response.first).to have_key('web_url')
      end

      it 'returns an array of all merge_requests' do
        path = endpoint_path + '?state'

        get api(path, user)

        expect_paginated_array_response([
          merge_request_merged.id, merge_request_locked.id,
          merge_request_closed.id, merge_request.id
        ])
        expect(json_response.last['title']).to eq(merge_request.title)
      end

      it 'returns an array of open merge_requests' do
        path = endpoint_path + '?state=opened'

        get api(path, user)

        expect_paginated_array_response([merge_request.id])
        expect(json_response.last['title']).to eq(merge_request.title)
      end

      it 'returns an array of closed merge_requests' do
        path = endpoint_path + '?state=closed'

        get api(path, user)

        expect_paginated_array_response([merge_request_closed.id])
        expect(json_response.first['title']).to eq(merge_request_closed.title)
      end

      it 'returns an array of merged merge_requests' do
        path = endpoint_path + '?state=merged'

        get api(path, user)

        expect_paginated_array_response([merge_request_merged.id])
        expect(json_response.first['title']).to eq(merge_request_merged.title)
      end

      it 'matches V4 response schema' do
        get api(endpoint_path, user)

        expect(response).to have_gitlab_http_status(200)
        expect(response).to match_response_schema('public_api/v4/merge_requests')
      end

      it 'returns an empty array if no issue matches milestone' do
        get api(endpoint_path, user), params: { milestone: '1.0.0' }

        expect_empty_array_response
      end

      it 'returns an empty array if milestone does not exist' do
        get api(endpoint_path, user), params: { milestone: 'foo' }

        expect_empty_array_response
      end

      it 'returns an array of merge requests in given milestone' do
        get api(endpoint_path, user), params: { milestone: '0.9' }

        closed_issues = json_response.select { |mr| mr['id'] == merge_request_closed.id }
        expect(closed_issues.length).to eq(1)
        expect(closed_issues.first['title']).to eq merge_request_closed.title
      end

      it 'returns an array of merge requests matching state in milestone' do
        get api(endpoint_path, user), params: { milestone: '0.9', state: 'closed' }

        expect_paginated_array_response([merge_request_closed.id])
        expect(json_response.first['id']).to eq(merge_request_closed.id)
      end

      context 'with labels' do
        include_context 'with labels'

        it 'returns an array of labeled merge requests' do
          path = endpoint_path + "?labels=#{label.title}"

          get api(path, user)

          expect_successful_response_with_paginated_array
          expect(json_response.length).to eq(1)
          expect(json_response.first['labels']).to eq([label2.title, label.title])
        end

        it 'returns an array of labeled merge requests where all labels match' do
          path = endpoint_path + "?labels=#{label.title},foo,bar"

          get api(path, user)

          expect_empty_array_response
        end

        it 'returns an empty array if no merge request matches labels' do
          path = endpoint_path + '?labels=foo,bar'

          get api(path, user)

          expect_empty_array_response
        end

        it 'returns an array of labeled merge requests where all labels match' do
          path = endpoint_path + "?labels[]=#{label.title}&labels[]=#{label2.title}"

          get api(path, user)

          expect_successful_response_with_paginated_array
          expect(json_response.length).to eq(1)
          expect(json_response.first['labels']).to eq([label2.title, label.title])
        end

        it 'returns an array of merge requests with any label when filtering by any label' do
          get api(endpoint_path, user), params: { labels: [" #{label.title} ", " #{label2.title} "] }

          expect_paginated_array_response([merge_request.id])
          expect(json_response.first['labels']).to eq([label2.title, label.title])
          expect(json_response.first['id']).to eq(merge_request.id)
        end

        it 'returns an array of merge requests with any label when filtering by any label' do
          get api(endpoint_path, user), params: { labels: ["#{label.title} , #{label2.title}"] }

          expect_paginated_array_response([merge_request.id])
          expect(json_response.first['labels']).to eq([label2.title, label.title])
          expect(json_response.first['id']).to eq(merge_request.id)
        end

        it 'returns an array of merge requests with any label when filtering by any label' do
          get api(endpoint_path, user), params: { labels: IssuesFinder::FILTER_ANY }

          expect_paginated_array_response([merge_request.id])
          expect(json_response.first['id']).to eq(merge_request.id)
        end

        it 'returns an array of merge requests without a label when filtering by no label' do
          get api(endpoint_path, user), params: { labels: IssuesFinder::FILTER_NONE }

          expect_response_contain_exactly(
            merge_request_merged.id, merge_request_locked.id, merge_request_closed.id
          )
        end
      end

      it 'returns an array of labeled merge requests that are merged for a milestone' do
        bug_label = create(:label, title: 'bug', color: '#FFAABB', project: project)

        mr1 = create(:merge_request, state: 'merged', source_project: project, target_project: project, milestone: milestone)
        mr2 = create(:merge_request, state: 'merged', source_project: project, target_project: project, milestone: milestone1)
        mr3 = create(:merge_request, state: 'closed', source_project: project, target_project: project, milestone: milestone1)
        _mr = create(:merge_request, state: 'merged', source_project: project, target_project: project, milestone: milestone1)

        create(:label_link, label: bug_label, target: mr1)
        create(:label_link, label: bug_label, target: mr2)
        create(:label_link, label: bug_label, target: mr3)

        path = endpoint_path + "?labels=#{bug_label.title}&milestone=#{milestone1.title}&state=merged"

        get api(path, user)

        expect_response_contain_exactly(mr2.id)
      end

      context 'with ordering' do
        before do
          @mr_later = mr_with_later_created_and_updated_at_time
          @mr_earlier = mr_with_earlier_created_and_updated_at_time
        end

        it 'returns an array of merge_requests in ascending order' do
          path = endpoint_path + '?sort=asc'

          get api(path, user)

          expect_paginated_array_response([
            merge_request_closed.id, merge_request_locked.id,
            merge_request_merged.id, merge_request.id
          ])
          response_dates = json_response.map { |merge_request| merge_request['created_at'] }
          expect(response_dates).to eq(response_dates.sort)
        end

        it 'returns an array of merge_requests in descending order' do
          path = endpoint_path + '?sort=desc'

          get api(path, user)

          expect_paginated_array_response([
            merge_request.id, merge_request_merged.id,
            merge_request_locked.id, merge_request_closed.id
          ])
          response_dates = json_response.map { |merge_request| merge_request['created_at'] }
          expect(response_dates).to eq(response_dates.sort.reverse)
        end

        context '2 merge requests with equal created_at' do
          let!(:closed_mr2) do
            create :merge_request,
                   state: 'closed',
                   milestone: milestone1,
                   author: user,
                   assignees: [user],
                   source_project: project,
                   target_project: project,
                   title: "Test",
                   created_at: @mr_earlier.created_at
          end

          it 'page breaks first page correctly' do
            get api("#{endpoint_path}?sort=desc&per_page=4", user)

            response_ids = json_response.map { |merge_request| merge_request['id'] }

            expect(response_ids).to include(closed_mr2.id)
            expect(response_ids).not_to include(@mr_earlier.id)
          end

          it 'page breaks second page correctly' do
            get api("#{endpoint_path}?sort=desc&per_page=4&page=2", user)

            response_ids = json_response.map { |merge_request| merge_request['id'] }

            expect(response_ids).not_to include(closed_mr2.id)
            expect(response_ids).to include(@mr_earlier.id)
          end
        end

        it 'returns an array of merge_requests ordered by updated_at' do
          path = endpoint_path + '?order_by=updated_at'

          get api(path, user)

          expect_paginated_array_response([
            merge_request.id, merge_request_locked.id,
            merge_request_merged.id, merge_request_closed.id
          ])
          response_dates = json_response.map { |merge_request| merge_request['updated_at'] }
          expect(response_dates).to eq(response_dates.sort.reverse)
        end

        it 'returns an array of merge_requests ordered by created_at' do
          path = endpoint_path + '?order_by=created_at&sort=asc'

          get api(path, user)

          expect_paginated_array_response([
            merge_request_closed.id, merge_request_locked.id,
            merge_request_merged.id, merge_request.id
          ])
          response_dates = json_response.map { |merge_request| merge_request['created_at'] }
          expect(response_dates).to eq(response_dates.sort)
        end
      end

      context 'source_branch param' do
        it 'returns merge requests with the given source branch' do
          get api(endpoint_path, user), params: { source_branch: merge_request_closed.source_branch, state: 'all' }

          expect_response_contain_exactly(
            merge_request_merged.id, merge_request_locked.id, merge_request_closed.id
          )
        end
      end

      context 'target_branch param' do
        it 'returns merge requests with the given target branch' do
          get api(endpoint_path, user), params: { target_branch: merge_request_closed.target_branch, state: 'all' }

          expect_response_contain_exactly(
            merge_request_merged.id, merge_request_locked.id, merge_request_closed.id
          )
        end
      end
    end
  end

  describe 'route shadowing' do
    include GrapePathHelpers::NamedRouteMatcher

    it 'does not occur' do
      path = api_v4_projects_merge_requests_path(id: 1)
      expect(path).to eq('/api/v4/projects/1/merge_requests')

      path = api_v4_projects_merge_requests_path(id: 1, merge_request_iid: 3)
      expect(path).to eq('/api/v4/projects/1/merge_requests/3')
    end
  end

  describe 'GET /merge_requests' do
    context 'when unauthenticated' do
      it 'returns an array of all merge requests' do
        get api('/merge_requests', user), params: { scope: 'all' }

        expect_response_contain_exactly(
          merge_request_merged.id, merge_request_locked.id,
          merge_request_closed.id, merge_request.id
        )
      end

      it "returns authentication error without any scope" do
        get api("/merge_requests")

        expect(response).to have_gitlab_http_status(401)
      end

      it "returns authentication error  when scope is assigned-to-me" do
        get api("/merge_requests"), params: { scope: 'assigned-to-me' }

        expect(response).to have_gitlab_http_status(401)
      end

      it "returns authentication error when scope is assigned_to_me" do
        get api("/merge_requests"), params: { scope: 'assigned_to_me' }

        expect(response).to have_gitlab_http_status(401)
      end

      it "returns authentication error  when scope is created-by-me" do
        get api("/merge_requests"), params: { scope: 'created-by-me' }

        expect(response).to have_gitlab_http_status(401)
      end
    end

    context 'when authenticated' do
      let!(:project2) { create(:project, :public, namespace: user.namespace) }
      let!(:merge_request2) { create(:merge_request, :simple, author: user, assignees: [user], source_project: project2, target_project: project2) }
      let(:user2) { create(:user) }

      it 'returns an array of all merge requests except unauthorized ones' do
        get api('/merge_requests', user), params: { scope: :all }

        expect_response_contain_exactly(
          merge_request_merged.id, merge_request2.id, merge_request_locked.id,
          merge_request_closed.id, merge_request.id
        )
      end

      it "returns an array of no merge_requests when wip=yes" do
        get api("/merge_requests", user), params: { wip: 'yes' }

        expect_empty_array_response
      end

      it "returns an array of no merge_requests when wip=no" do
        get api("/merge_requests", user), params: { wip: 'no' }

        expect_response_contain_exactly(
          merge_request_merged.id, merge_request2.id, merge_request_locked.id,
          merge_request_closed.id, merge_request.id
        )
      end

      it 'does not return unauthorized merge requests' do
        private_project = create(:project, :private)
        merge_request3 = create(:merge_request, :simple, source_project: private_project, target_project: private_project, source_branch: 'other-branch')

        get api('/merge_requests', user), params: { scope: :all }

        expect_response_contain_exactly(
          merge_request_merged.id, merge_request2.id, merge_request_locked.id,
          merge_request_closed.id, merge_request.id
        )
        expect(json_response.map { |mr| mr['id'] }).not_to include(merge_request3.id)
      end

      it 'returns an array of merge requests created by current user if no scope is given' do
        merge_request3 = create(:merge_request, :simple, author: user2, assignees: [user], source_project: project2, target_project: project2, source_branch: 'other-branch')

        get api('/merge_requests', user2)

        expect_response_contain_exactly(merge_request3.id)
      end

      it 'returns an array of merge requests authored by the given user' do
        merge_request3 = create(:merge_request, :simple, author: user2, assignees: [user], source_project: project2, target_project: project2, source_branch: 'other-branch')

        get api('/merge_requests', user), params: { author_id: user2.id, scope: :all }

        expect_response_contain_exactly(merge_request3.id)
      end

      it 'returns an array of merge requests assigned to the given user' do
        merge_request3 = create(:merge_request, :simple, author: user, assignees: [user2], source_project: project2, target_project: project2, source_branch: 'other-branch')

        get api('/merge_requests', user), params: { assignee_id: user2.id, scope: :all }

        expect_response_contain_exactly(merge_request3.id)
      end

      it 'returns an array of merge requests with no assignee' do
        merge_request3 = create(:merge_request, :simple, author: user, source_project: project2, target_project: project2, source_branch: 'other-branch')

        get api('/merge_requests', user), params: { assignee_id: 'None', scope: :all }

        expect_response_contain_exactly(merge_request3.id)
      end

      it 'returns an array of merge requests with any assignee' do
        # This MR with no assignee should not be returned
        create(:merge_request, :simple, author: user, source_project: project2, target_project: project2, source_branch: 'other-branch')

        get api('/merge_requests', user), params: { assignee_id: 'Any', scope: :all }

        expect_response_contain_exactly(
          merge_request_merged.id, merge_request2.id, merge_request_locked.id,
          merge_request_closed.id, merge_request.id
        )
      end

      it 'returns an array of merge requests assigned to me' do
        merge_request3 = create(:merge_request, :simple, author: user, assignees: [user2], source_project: project2, target_project: project2, source_branch: 'other-branch')

        get api('/merge_requests', user2), params: { scope: 'assigned_to_me' }

        expect_response_contain_exactly(merge_request3.id)
      end

      it 'returns an array of merge requests assigned to me (kebab-case)' do
        merge_request3 = create(:merge_request, :simple, author: user, assignees: [user2], source_project: project2, target_project: project2, source_branch: 'other-branch')

        get api('/merge_requests', user2), params: { scope: 'assigned-to-me' }

        expect_response_contain_exactly(merge_request3.id)
      end

      it 'returns an array of merge requests created by me' do
        merge_request3 = create(:merge_request, :simple, author: user2, assignees: [user], source_project: project2, target_project: project2, source_branch: 'other-branch')

        get api('/merge_requests', user2), params: { scope: 'created_by_me' }

        expect_response_contain_exactly(merge_request3.id)
      end

      it 'returns an array of merge requests created by me (kebab-case)' do
        merge_request3 = create(:merge_request, :simple, author: user2, assignees: [user], source_project: project2, target_project: project2, source_branch: 'other-branch')

        get api('/merge_requests', user2), params: { scope: 'created-by-me' }

        expect_response_contain_exactly(merge_request3.id)
      end

      it 'returns merge requests reacted by the authenticated user by the given emoji' do
        merge_request3 = create(:merge_request, :simple, author: user, assignees: [user], source_project: project2, target_project: project2, source_branch: 'other-branch')
        award_emoji = create(:award_emoji, awardable: merge_request3, user: user2, name: 'star')

        get api('/merge_requests', user2), params: { my_reaction_emoji: award_emoji.name, scope: 'all' }

        expect_response_contain_exactly(merge_request3.id)
      end

      context 'source_branch param' do
        it 'returns merge requests with the given source branch' do
          get api('/merge_requests', user), params: { source_branch: merge_request_closed.source_branch, state: 'all' }

          expect_response_contain_exactly(
            merge_request_merged.id, merge_request_locked.id, merge_request_closed.id
          )
        end
      end

      context 'target_branch param' do
        it 'returns merge requests with the given target branch' do
          get api('/merge_requests', user), params: { target_branch: merge_request_closed.target_branch, state: 'all' }

          expect_response_contain_exactly(
            merge_request_merged.id, merge_request_locked.id, merge_request_closed.id
          )
        end
      end

      it 'returns merge requests created before a specific date' do
        merge_request2 = create(:merge_request, :simple, source_project: project, target_project: project, source_branch: 'feature_1', created_at: Date.new(2000, 1, 1))

        get api('/merge_requests?created_before=2000-01-02T00:00:00.060Z', user)

        expect_response_contain_exactly(merge_request2.id)
      end

      it 'returns merge requests created after a specific date' do
        merge_request2 = create(:merge_request, :simple, source_project: project, target_project: project, source_branch: 'feature_1', created_at: 1.week.from_now)

        get api("/merge_requests?created_after=#{merge_request2.created_at}", user)

        expect_response_contain_exactly(merge_request2.id)
      end

      it 'returns merge requests updated before a specific date' do
        merge_request2 = create(:merge_request, :simple, source_project: project, target_project: project, source_branch: 'feature_1', updated_at: Date.new(2000, 1, 1))

        get api('/merge_requests?updated_before=2000-01-02T00:00:00.060Z', user)

        expect_response_contain_exactly(merge_request2.id)
      end

      it 'returns merge requests updated after a specific date' do
        merge_request2 = create(:merge_request, :simple, source_project: project, target_project: project, source_branch: 'feature_1', updated_at: 1.week.from_now)

        get api("/merge_requests?updated_after=#{merge_request2.updated_at}", user)

        expect_response_contain_exactly(merge_request2.id)
      end

      context 'search params' do
        before do
          merge_request.update(title: 'Search title', description: 'Search description')
        end

        it 'returns merge requests matching given search string for title' do
          get api("/merge_requests", user), params: { search: merge_request.title }

          expect_response_contain_exactly(merge_request.id)
        end

        it 'returns merge requests matching given search string for title and scoped in title' do
          get api("/merge_requests", user), params: { search: merge_request.title, in: 'title' }

          expect_response_contain_exactly(merge_request.id)
        end

        it 'returns an empty array if no merge request matches given search string for description and scoped in title' do
          get api("/merge_requests", user), params: { search: merge_request.description, in: 'title' }

          expect_empty_array_response
        end

        it 'returns merge requests for project matching given search string for description' do
          get api("/merge_requests", user), params: { project_id: project.id, search: merge_request.description }

          expect_response_contain_exactly(merge_request.id)
        end
      end

      context 'state param' do
        it 'returns merge requests with the given state' do
          get api('/merge_requests', user), params: { state: 'locked' }

          expect_response_contain_exactly(merge_request_locked.id)
        end
      end
    end
  end

  describe "GET /projects/:id/merge_requests" do
    let(:endpoint_path) { "/projects/#{project.id}/merge_requests" }

    it_behaves_like 'merge requests list'

    it "returns 404 for non public projects" do
      project = create(:project, :private)

      get api("/projects/#{project.id}/merge_requests")

      expect(response).to have_gitlab_http_status(404)
    end

    it "returns an array of no merge_requests when wip=yes" do
      get api("/projects/#{project.id}/merge_requests", user), params: { wip: 'yes' }

      expect_empty_array_response
    end

    it 'returns merge_request by "iids" array' do
      get api(endpoint_path, user), params: { iids: [merge_request.iid, merge_request_closed.iid] }

      expect_paginated_array_response([merge_request_closed.id, merge_request.id])
      expect(json_response.first['title']).to eq merge_request_closed.title
      expect(json_response.first['id']).to eq merge_request_closed.id
    end

    context 'a project which enforces all discussions to be resolved' do
      let!(:project) { create(:project, :repository, only_allow_merge_if_all_discussions_are_resolved: true) }

      it 'avoids N+1 queries' do
        control = ActiveRecord::QueryRecorder.new do
          get api("/projects/#{project.id}/merge_requests", user)
        end.count

        create(:merge_request, author: user, assignees: [user], source_project: project, target_project: project, created_at: base_time)

        expect do
          get api("/projects/#{project.id}/merge_requests", user)
        end.not_to exceed_query_limit(control)
      end
    end
  end

  describe "GET /groups/:id/merge_requests" do
    let!(:group) { create(:group, :public) }
    let!(:project) { create(:project, :public, :repository, creator: user, namespace: group, only_allow_merge_if_pipeline_succeeds: false) }
    let(:endpoint_path) { "/groups/#{group.id}/merge_requests" }

    before do
      group.add_reporter(user)
    end

    it_behaves_like 'merge requests list'

    context 'when have subgroups' do
      let!(:group) { create(:group, :public) }
      let!(:subgroup) { create(:group, parent: group) }
      let!(:project) { create(:project, :public, :repository, creator: user, namespace: subgroup, only_allow_merge_if_pipeline_succeeds: false) }

      it_behaves_like 'merge requests list'
    end

    describe "#to_reference" do
      it 'exposes reference path in context of group' do
        get api("/groups/#{group.id}/merge_requests", user)

        expect(json_response.first['references']['short']).to eq("!#{merge_request_merged.iid}")
        expect(json_response.first['references']['relative']).to eq("#{merge_request_merged.target_project.path}!#{merge_request_merged.iid}")
        expect(json_response.first['references']['full']).to eq("#{merge_request_merged.target_project.full_path}!#{merge_request_merged.iid}")
      end

      context 'referencing from parent group' do
        let(:parent_group) { create(:group) }

        before do
          group.update(parent_id: parent_group.id)
          merge_request_merged.reload
        end

        it 'exposes reference path in context of parent group' do
          get api("/groups/#{parent_group.id}/merge_requests")

          expect(json_response.first['references']['short']).to eq("!#{merge_request_merged.iid}")
          expect(json_response.first['references']['relative']).to eq("#{merge_request_merged.target_project.full_path}!#{merge_request_merged.iid}")
          expect(json_response.first['references']['full']).to eq("#{merge_request_merged.target_project.full_path}!#{merge_request_merged.iid}")
        end
      end
    end

    context 'with archived projects' do
      let(:project2) { create(:project, :public, :archived, namespace: group) }
      let!(:merge_request_archived) { create(:merge_request, title: 'archived mr', author: user, source_project: project2, target_project: project2) }

      it 'returns an array excluding merge_requests from archived projects' do
        get api(endpoint_path, user)

        expect_response_contain_exactly(
          merge_request_merged.id, merge_request_locked.id,
          merge_request_closed.id, merge_request.id
        )
      end

      context 'with non_archived param set as false' do
        it 'returns an array including merge_requests from archived projects' do
          path = endpoint_path + '?non_archived=false'

          get api(path, user)

          expect_response_contain_exactly(
            merge_request_merged.id, merge_request_archived.id, merge_request_locked.id,
            merge_request_closed.id, merge_request.id
          )
        end
      end
    end
  end

  describe "GET /projects/:id/merge_requests/:merge_request_iid" do
    it 'matches json schema' do
      merge_request = create(:merge_request, :with_test_reports, milestone: milestone1, author: user, assignees: [user], source_project: project, target_project: project, title: "Test", created_at: base_time)
      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user)

      expect(response).to have_gitlab_http_status(200)
      expect(response).to match_response_schema('public_api/v4/merge_request')
    end

    it 'exposes known attributes' do
      create(:award_emoji, :downvote, awardable: merge_request)
      create(:award_emoji, :upvote, awardable: merge_request)

      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user)

      expect(response).to have_gitlab_http_status(200)
      expect(json_response['id']).to eq(merge_request.id)
      expect(json_response['iid']).to eq(merge_request.iid)
      expect(json_response['project_id']).to eq(merge_request.project.id)
      expect(json_response['title']).to eq(merge_request.title)
      expect(json_response['description']).to eq(merge_request.description)
      expect(json_response['state']).to eq(merge_request.state)
      expect(json_response['created_at']).to be_present
      expect(json_response['updated_at']).to be_present
      expect(json_response['labels']).to eq(merge_request.label_names)
      expect(json_response['milestone']).to be_a Hash
      expect(json_response['assignee']).to be_a Hash
      expect(json_response['author']).to be_a Hash
      expect(json_response['target_branch']).to eq(merge_request.target_branch)
      expect(json_response['source_branch']).to eq(merge_request.source_branch)
      expect(json_response['upvotes']).to eq(1)
      expect(json_response['downvotes']).to eq(1)
      expect(json_response['source_project_id']).to eq(merge_request.source_project.id)
      expect(json_response['target_project_id']).to eq(merge_request.target_project.id)
      expect(json_response['work_in_progress']).to be_falsy
      expect(json_response['merge_when_pipeline_succeeds']).to be_falsy
      expect(json_response['merge_status']).to eq('can_be_merged')
      expect(json_response['should_close_merge_request']).to be_falsy
      expect(json_response['force_close_merge_request']).to be_falsy
      expect(json_response['changes_count']).to eq(merge_request.merge_request_diff.real_size)
      expect(json_response['merge_error']).to eq(merge_request.merge_error)
      expect(json_response['user']['can_merge']).to be_truthy
      expect(json_response).not_to include('rebase_in_progress')
      expect(json_response['has_conflicts']).to be_falsy
      expect(json_response['blocking_discussions_resolved']).to be_truthy
      expect(json_response['references']['short']).to eq("!#{merge_request.iid}")
      expect(json_response['references']['relative']).to eq("!#{merge_request.iid}")
      expect(json_response['references']['full']).to eq("#{merge_request.target_project.full_path}!#{merge_request.iid}")
    end

    it 'exposes description and title html when render_html is true' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: { render_html: true }

      expect(response).to have_gitlab_http_status(200)

      expect(json_response).to include('title_html', 'description_html')
    end

    it 'exposes rebase_in_progress when include_rebase_in_progress is true' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: { include_rebase_in_progress: true }

      expect(response).to have_gitlab_http_status(200)

      expect(json_response).to include('rebase_in_progress')
    end

    context 'merge_request_metrics' do
      let(:pipeline) { create(:ci_empty_pipeline) }

      before do
        merge_request.metrics.update!(merged_by: user,
                                      latest_closed_by: user,
                                      latest_closed_at: 1.hour.ago,
                                      merged_at: 2.hours.ago,
                                      pipeline: pipeline,
                                      latest_build_started_at: 3.hours.ago,
                                      latest_build_finished_at: 1.hour.ago,
                                      first_deployed_to_production_at: 3.minutes.ago)
      end

      it 'has fields from merge request metrics' do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user)

        expect(json_response).to include('merged_by',
          'merged_at',
          'closed_by',
          'closed_at',
          'latest_build_started_at',
          'latest_build_finished_at',
          'first_deployed_to_production_at',
          'pipeline')
      end

      it 'returns correct values' do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.reload.iid}", user)

        expect(json_response['merged_by']['id']).to eq(merge_request.metrics.merged_by_id)
        expect(Time.parse json_response['merged_at']).to be_like_time(merge_request.metrics.merged_at)
        expect(json_response['closed_by']['id']).to eq(merge_request.metrics.latest_closed_by_id)
        expect(Time.parse json_response['closed_at']).to be_like_time(merge_request.metrics.latest_closed_at)
        expect(json_response['pipeline']['id']).to eq(merge_request.metrics.pipeline_id)
        expect(Time.parse json_response['latest_build_started_at']).to be_like_time(merge_request.metrics.latest_build_started_at)
        expect(Time.parse json_response['latest_build_finished_at']).to be_like_time(merge_request.metrics.latest_build_finished_at)
        expect(Time.parse json_response['first_deployed_to_production_at']).to be_like_time(merge_request.metrics.first_deployed_to_production_at)
      end
    end

    context 'head_pipeline' do
      before do
        merge_request.update(head_pipeline: create(:ci_pipeline))
        merge_request.project.project_feature.update(builds_access_level: 10)
      end

      context 'when user can read the pipeline' do
        it 'exposes pipeline information' do
          get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user)

          expect(json_response).to include('head_pipeline')
        end
      end

      context 'when user can not read the pipeline' do
        let(:guest) { create(:user) }

        it 'does not expose pipeline information' do
          get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", guest)

          expect(json_response).not_to include('head_pipeline')
        end
      end
    end

    it 'returns the commits behind the target branch when include_diverged_commits_count is present' do
      allow_any_instance_of(merge_request.class).to receive(:diverged_commits_count).and_return(1)

      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: { include_diverged_commits_count: true }

      expect(response).to have_gitlab_http_status(200)
      expect(json_response['diverged_commits_count']).to eq(1)
    end

    it "returns a 404 error if merge_request_iid not found" do
      get api("/projects/#{project.id}/merge_requests/0", user)
      expect(response).to have_gitlab_http_status(404)
    end

    it "returns a 404 error if merge_request `id` is used instead of iid" do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.id}", user)

      expect(response).to have_gitlab_http_status(404)
    end

    context 'Work in Progress' do
      let!(:merge_request_wip) { create(:merge_request, author: user, assignees: [user], source_project: project, target_project: project, title: "WIP: Test", created_at: base_time + 1.second) }

      it "returns merge request" do
        get api("/projects/#{project.id}/merge_requests/#{merge_request_wip.iid}", user)

        expect(response).to have_gitlab_http_status(200)
        expect(json_response['work_in_progress']).to eq(true)
      end
    end

    context 'when a merge request has more than the changes limit' do
      it "returns a string indicating that more changes were made" do
        stub_const('Commit::DIFF_HARD_LIMIT_FILES', 5)

        merge_request_overflow = create(:merge_request, :simple,
                                        author: user,
                                        assignees: [user],
                                        source_project: project,
                                        source_branch: 'expand-collapse-files',
                                        target_project: project,
                                        target_branch: 'master')

        get api("/projects/#{project.id}/merge_requests/#{merge_request_overflow.iid}", user)

        expect(response).to have_gitlab_http_status(200)
        expect(json_response['changes_count']).to eq('5+')
      end
    end

    context 'for forked projects' do
      let(:user2) { create(:user) }
      let(:project) { create(:project, :public, :repository) }
      let(:forked_project) { fork_project(project, user2, repository: true) }
      let(:merge_request) do
        create(:merge_request,
               source_project: forked_project,
               target_project: project,
               source_branch: 'fixes',
               allow_collaboration: true)
      end

      it 'includes the `allow_collaboration` field', :sidekiq_might_not_need_inline do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user)

        expect(json_response['allow_collaboration']).to be_truthy
        expect(json_response['allow_maintainer_to_push']).to be_truthy
      end
    end

    it 'indicates if a user cannot merge the MR' do
      user2 = create(:user)
      project.add_reporter(user2)

      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user2)

      expect(json_response['user']['can_merge']).to be_falsy
    end

    context 'when merge request is unchecked' do
      before do
        merge_request.mark_as_unchecked!
      end

      it 'checks mergeability asynchronously' do
        expect_next_instance_of(MergeRequests::MergeabilityCheckService) do |service|
          expect(service).not_to receive(:execute)
          expect(service).to receive(:async_execute)
        end

        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user)
      end
    end
  end

  describe 'GET /projects/:id/merge_requests/:merge_request_iid/participants' do
    it_behaves_like 'issuable participants endpoint' do
      let(:entity) { merge_request }
    end
  end

  describe 'GET /projects/:id/merge_requests/:merge_request_iid/commits' do
    it 'returns a 200 when merge request is valid' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/commits", user)
      commit = merge_request.commits.first

      expect_successful_response_with_paginated_array
      expect(json_response.size).to eq(merge_request.commits.size)
      expect(json_response.first['id']).to eq(commit.id)
      expect(json_response.first['title']).to eq(commit.title)
    end

    it 'returns a 404 when merge_request_iid not found' do
      get api("/projects/#{project.id}/merge_requests/0/commits", user)
      expect(response).to have_gitlab_http_status(404)
    end

    it 'returns a 404 when merge_request id is used instead of iid' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.id}/commits", user)

      expect(response).to have_gitlab_http_status(404)
    end
  end

  describe 'GET /projects/:id/merge_requests/:merge_request_iid/:context_commits' do
    it 'returns a 200 when merge request is valid' do
      context_commit = merge_request.context_commits.first

      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/context_commits", user)

      expect_successful_response_with_paginated_array
      expect(json_response.size).to eq(merge_request.context_commits.size)
      expect(json_response.first['id']).to eq(context_commit.id)
      expect(json_response.first['title']).to eq(context_commit.title)
    end

    it 'returns a 404 when merge_request_iid not found' do
      get api("/projects/#{project.id}/merge_requests/0/context_commits", user)
      expect(response).to have_gitlab_http_status(404)
    end
  end

  describe 'GET /projects/:id/merge_requests/:merge_request_iid/changes' do
    it 'returns the change information of the merge_request' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/changes", user)

      expect(response).to have_gitlab_http_status(200)
      expect(json_response['changes'].size).to eq(merge_request.diffs.size)
    end

    it 'returns a 404 when merge_request_iid not found' do
      get api("/projects/#{project.id}/merge_requests/0/changes", user)
      expect(response).to have_gitlab_http_status(404)
    end

    it 'returns a 404 when merge_request id is used instead of iid' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.id}/changes", user)

      expect(response).to have_gitlab_http_status(404)
    end
  end

  describe 'GET /projects/:id/merge_requests/:merge_request_iid/pipelines' do
    context 'when authorized' do
      let!(:pipeline) { create(:ci_empty_pipeline, project: project, user: user, ref: merge_request.source_branch, sha: merge_request.diff_head_sha) }
      let!(:pipeline2) { create(:ci_empty_pipeline, project: project) }

      it 'returns a paginated array of corresponding pipelines' do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/pipelines")

        expect_successful_response_with_paginated_array
        expect(json_response.count).to eq(1)
        expect(json_response.first['id']).to eq(pipeline.id)
      end

      it 'exposes basic attributes' do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/pipelines")

        expect(response).to have_gitlab_http_status(200)
        expect(response).to match_response_schema('public_api/v4/pipelines')
      end

      it 'returns 404 if MR does not exist' do
        get api("/projects/#{project.id}/merge_requests/777/pipelines")

        expect(response).to have_gitlab_http_status(404)
      end
    end

    context 'when unauthorized' do
      it 'returns 403' do
        project = create(:project, public_builds: false)
        merge_request = create(:merge_request, :simple, source_project: project)
        guest = create(:user)
        project.add_guest(guest)

        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/pipelines", guest)

        expect(response).to have_gitlab_http_status(403)
      end
    end
  end

  describe 'POST /projects/:id/merge_requests/:merge_request_iid/pipelines' do
    before do
      stub_ci_pipeline_yaml_file(YAML.dump({
        rspec: {
          script: 'ls',
          only: ['merge_requests']
        }
      }))
    end

    let(:project) do
      create(:project, :private, :repository,
        creator: user,
        namespace: user.namespace,
        only_allow_merge_if_pipeline_succeeds: false)
    end

    let(:merge_request) do
      create(:merge_request, :with_detached_merge_request_pipeline,
        milestone: milestone1,
        author: user,
        assignees: [user],
        source_project: project,
        target_project: project,
        title: 'Test',
        created_at: base_time)
    end

    let(:merge_request_iid)  { merge_request.iid }
    let(:authenticated_user) { user }

    let(:request) do
      post api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/pipelines", authenticated_user)
    end

    context 'when authorized' do
      it 'creates and returns the new Pipeline' do
        expect { request }.to change(Ci::Pipeline, :count).by(1)
        expect(response).to have_gitlab_http_status(200)
        expect(json_response).to be_a Hash
      end
    end

    context 'when unauthorized' do
      let(:authenticated_user) { create(:user) }

      it 'responds with a blank 404' do
        expect { request }.not_to change(Ci::Pipeline, :count)
        expect(response).to have_gitlab_http_status(404)
      end
    end

    context 'when the merge request does not exist' do
      let(:merge_request_iid) { 777 }

      it 'responds with a blank 404' do
        expect { request }.not_to change(Ci::Pipeline, :count)
        expect(response).to have_gitlab_http_status(404)
      end
    end
  end

  describe 'POST /projects/:id/merge_requests' do
    context 'support for deprecated assignee_id' do
      let(:params) do
        {
          title: 'Test merge request',
          source_branch: 'feature_conflict',
          target_branch: 'master',
          author_id: user.id,
          assignee_id: user2.id
        }
      end

      it 'creates a new merge request' do
        post api("/projects/#{project.id}/merge_requests", user), params: params

        expect(response).to have_gitlab_http_status(201)
        expect(json_response['title']).to eq('Test merge request')
        expect(json_response['assignee']['name']).to eq(user2.name)
        expect(json_response['assignees'].first['name']).to eq(user2.name)
      end

      it 'creates a new merge request when assignee_id is empty' do
        params[:assignee_id] = ''

        post api("/projects/#{project.id}/merge_requests", user), params: params

        expect(response).to have_gitlab_http_status(201)
        expect(json_response['title']).to eq('Test merge request')
        expect(json_response['assignee']).to be_nil
      end

      it 'filters assignee_id of unauthorized user' do
        private_project = create(:project, :private, :repository)
        another_user = create(:user)
        private_project.add_maintainer(user)
        params[:assignee_id] = another_user.id

        post api("/projects/#{private_project.id}/merge_requests", user), params: params

        expect(response).to have_gitlab_http_status(201)
        expect(json_response['assignee']).to be_nil
      end
    end

    context 'single assignee restrictions' do
      let(:params) do
        {
          title: 'Test merge request',
          source_branch: 'feature_conflict',
          target_branch: 'master',
          author_id: user.id,
          assignee_ids: [user.id, user2.id]
        }
      end

      it 'creates a new project merge request with no more than one assignee' do
        post api("/projects/#{project.id}/merge_requests", user), params: params

        expect(response).to have_gitlab_http_status(201)
        expect(json_response['title']).to eq('Test merge request')
        expect(json_response['assignees'].count).to eq(1)
        expect(json_response['assignees'].first['name']).to eq(user.name)
        expect(json_response.dig('assignee', 'name')).to eq(user.name)
      end
    end

    context 'between branches projects' do
      context 'different labels' do
        let(:params) do
          {
            title: 'Test merge_request',
            source_branch: 'feature_conflict',
            target_branch: 'master',
            author_id: user.id,
            milestone_id: milestone.id,
            squash: true
          }
        end

        shared_examples_for 'creates merge request with labels' do
          it 'returns merge_request' do
            params[:labels] = labels
            post api("/projects/#{project.id}/merge_requests", user), params: params

            expect(response).to have_gitlab_http_status(201)
            expect(json_response['title']).to eq('Test merge_request')
            expect(json_response['labels']).to eq(%w(label label2))
            expect(json_response['milestone']['id']).to eq(milestone.id)
            expect(json_response['squash']).to be_truthy
            expect(json_response['force_remove_source_branch']).to be_falsy
          end
        end

        it_behaves_like 'creates merge request with labels' do
          let(:labels) { 'label, label2' }
        end

        it_behaves_like 'creates merge request with labels' do
          let(:labels) { %w(label label2) }
        end

        it_behaves_like 'creates merge request with labels' do
          let(:labels) { %w(label label2) }
        end

        it 'creates merge request with special label names' do
          params[:labels] = 'label, label?, label&foo, ?, &'
          post api("/projects/#{project.id}/merge_requests", user), params: params

          expect(response).to have_gitlab_http_status(201)
          expect(json_response['labels']).to include 'label'
          expect(json_response['labels']).to include 'label?'
          expect(json_response['labels']).to include 'label&foo'
          expect(json_response['labels']).to include '?'
          expect(json_response['labels']).to include '&'
        end

        it 'creates merge request with special label names as array' do
          params[:labels] = ['label', 'label?', 'label&foo, ?, &', '1, 2', 3, 4]
          post api("/projects/#{project.id}/merge_requests", user), params: params

          expect(response).to have_gitlab_http_status(201)
          expect(json_response['labels']).to include 'label'
          expect(json_response['labels']).to include 'label?'
          expect(json_response['labels']).to include 'label&foo'
          expect(json_response['labels']).to include '?'
          expect(json_response['labels']).to include '&'
          expect(json_response['labels']).to include '1'
          expect(json_response['labels']).to include '2'
          expect(json_response['labels']).to include '3'
          expect(json_response['labels']).to include '4'
        end

        it 'empty label param does not add any labels' do
          params[:labels] = ''
          post api("/projects/#{project.id}/merge_requests", user), params: params

          expect(response).to have_gitlab_http_status(201)
          expect(json_response['labels']).to eq([])
        end

        it 'empty label param as array does not add any labels, but only explicitly as json' do
          params[:labels] = []
          post api("/projects/#{project.id}/merge_requests", user),
            params: params.to_json,
            headers: { 'Content-Type': 'application/json' }

          expect(response).to have_gitlab_http_status(201)
          expect(json_response['labels']).to eq([])
        end

        it 'empty label param as array, does not add any labels' do
          params[:labels] = []
          post api("/projects/#{project.id}/merge_requests", user), params: params

          expect(response).to have_gitlab_http_status(201)
          expect(json_response['labels']).to eq([])
        end

        it 'array with one empty string element does not add labels' do
          params[:labels] = ['']
          post api("/projects/#{project.id}/merge_requests", user), params: params

          expect(response).to have_gitlab_http_status(201)
          expect(json_response['labels']).to eq([])
        end

        it 'array with multiple empty string elements, does not add labels' do
          params[:labels] = ['', '', '']
          post api("/projects/#{project.id}/merge_requests", user), params: params

          expect(response).to have_gitlab_http_status(201)
          expect(json_response['labels']).to eq([])
        end
      end

      it "returns 422 when source_branch equals target_branch" do
        post api("/projects/#{project.id}/merge_requests", user),
        params: { title: "Test merge_request", source_branch: "master", target_branch: "master", author: user }
        expect(response).to have_gitlab_http_status(422)
      end

      it "returns 400 when source_branch is missing" do
        post api("/projects/#{project.id}/merge_requests", user),
        params: { title: "Test merge_request", target_branch: "master", author: user }
        expect(response).to have_gitlab_http_status(400)
      end

      it "returns 400 when target_branch is missing" do
        post api("/projects/#{project.id}/merge_requests", user),
        params: { title: "Test merge_request", source_branch: "markdown", author: user }
        expect(response).to have_gitlab_http_status(400)
      end

      it "returns 400 when title is missing" do
        post api("/projects/#{project.id}/merge_requests", user),
        params: { target_branch: 'master', source_branch: 'markdown' }
        expect(response).to have_gitlab_http_status(400)
      end

      context 'with existing MR' do
        before do
          post api("/projects/#{project.id}/merge_requests", user),
               params: {
                 title: 'Test merge_request',
                 source_branch: 'feature_conflict',
                 target_branch: 'master',
                 author: user
               }
          @mr = MergeRequest.all.last
        end

        it 'returns 409 when MR already exists for source/target' do
          expect do
            post api("/projects/#{project.id}/merge_requests", user),
                 params: {
                   title: 'New test merge_request',
                   source_branch: 'feature_conflict',
                   target_branch: 'master',
                   author: user
                 }
          end.to change { MergeRequest.count }.by(0)
          expect(response).to have_gitlab_http_status(409)
        end
      end

      context 'accepts remove_source_branch parameter' do
        let(:params) do
          { title: 'Test merge_request',
            source_branch: 'feature_conflict',
            target_branch: 'master',
            author: user }
        end

        it 'sets force_remove_source_branch to false' do
          post api("/projects/#{project.id}/merge_requests", user), params: params.merge(remove_source_branch: false)

          expect(json_response['force_remove_source_branch']).to be_falsy
        end

        it 'sets force_remove_source_branch to true' do
          post api("/projects/#{project.id}/merge_requests", user), params: params.merge(remove_source_branch: true)

          expect(json_response['force_remove_source_branch']).to be_truthy
        end
      end
    end

    context 'forked projects', :sidekiq_might_not_need_inline do
      let!(:user2) { create(:user) }
      let(:project) { create(:project, :public, :repository) }
      let!(:forked_project) { fork_project(project, user2, repository: true) }
      let!(:unrelated_project) { create(:project, namespace: create(:user).namespace, creator_id: user2.id) }

      before do
        forked_project.add_reporter(user2)
      end

      it "returns merge_request" do
        post api("/projects/#{forked_project.id}/merge_requests", user2),
          params: { title: 'Test merge_request', source_branch: "feature_conflict", target_branch: "master", author: user2, target_project_id: project.id, description: 'Test description for Test merge_request' }
        expect(response).to have_gitlab_http_status(201)
        expect(json_response['title']).to eq('Test merge_request')
        expect(json_response['description']).to eq('Test description for Test merge_request')
      end

      it "does not return 422 when source_branch equals target_branch" do
        expect(project.id).not_to eq(forked_project.id)
        expect(forked_project.forked?).to be_truthy
        expect(forked_project.forked_from_project).to eq(project)
        post api("/projects/#{forked_project.id}/merge_requests", user2),
        params: { title: 'Test merge_request', source_branch: "master", target_branch: "master", author: user2, target_project_id: project.id }
        expect(response).to have_gitlab_http_status(201)
        expect(json_response['title']).to eq('Test merge_request')
      end

      it 'returns 403 when target project has disabled merge requests' do
        project.project_feature.update(merge_requests_access_level: 0)

        post api("/projects/#{forked_project.id}/merge_requests", user2),
             params: {
               title: 'Test',
               target_branch: 'master',
               source_branch: 'markdown',
               author: user2,
               target_project_id: project.id
             }

        expect(response).to have_gitlab_http_status(403)
      end

      it "returns 400 when source_branch is missing" do
        post api("/projects/#{forked_project.id}/merge_requests", user2),
        params: { title: 'Test merge_request', target_branch: "master", author: user2, target_project_id: project.id }
        expect(response).to have_gitlab_http_status(400)
      end

      it "returns 400 when target_branch is missing" do
        post api("/projects/#{forked_project.id}/merge_requests", user2),
        params: { title: 'Test merge_request', target_branch: "master", author: user2, target_project_id: project.id }
        expect(response).to have_gitlab_http_status(400)
      end

      it "returns 400 when title is missing" do
        post api("/projects/#{forked_project.id}/merge_requests", user2),
        params: { target_branch: 'master', source_branch: 'markdown', author: user2, target_project_id: project.id }
        expect(response).to have_gitlab_http_status(400)
      end

      it 'allows setting `allow_collaboration`', :sidekiq_might_not_need_inline do
        post api("/projects/#{forked_project.id}/merge_requests", user2),
             params: { title: 'Test merge_request', source_branch: "feature_conflict", target_branch: "master", author: user2, target_project_id: project.id, allow_collaboration: true }
        expect(response).to have_gitlab_http_status(201)
        expect(json_response['allow_collaboration']).to be_truthy
        expect(json_response['allow_maintainer_to_push']).to be_truthy
      end

      context 'when target_branch and target_project_id is specified' do
        let(:params) do
          { title: 'Test merge_request',
            target_branch: 'master',
            source_branch: 'markdown',
            author: user2,
            target_project_id: unrelated_project.id }
        end

        it 'returns 422 if targeting a different fork' do
          unrelated_project.add_developer(user2)

          post api("/projects/#{forked_project.id}/merge_requests", user2), params: params

          expect(response).to have_gitlab_http_status(422)
        end

        it 'returns 403 if targeting a different fork which user can not access' do
          post api("/projects/#{forked_project.id}/merge_requests", user2), params: params

          expect(response).to have_gitlab_http_status(403)
        end
      end

      it "returns 201 when target_branch is specified and for the same project", :sidekiq_might_not_need_inline do
        post api("/projects/#{forked_project.id}/merge_requests", user2),
        params: { title: 'Test merge_request', target_branch: 'master', source_branch: 'markdown', author: user2, target_project_id: forked_project.id }
        expect(response).to have_gitlab_http_status(201)
      end
    end
  end

  describe "POST /projects/:id/merge_requests/:merge_request_iid/context_commits" do
    let(:merge_request_iid)  { merge_request.iid }
    let(:authenticated_user) { user }
    let(:commit) { project.repository.commit }

    let(:params) do
      {
        commits: [commit.id]
      }
    end

    let(:params_empty_commits) do
      {
        commits: []
      }
    end

    let(:params_invalid_shas) do
      {
        commits: ['invalid']
      }
    end

    describe 'when authenticated' do
      it 'creates and returns the new context commit' do
        post api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/context_commits", authenticated_user), params: params
        expect(response).to have_gitlab_http_status(201)
        expect(json_response).to be_an Array
        expect(json_response.first['short_id']).to eq(commit.short_id)
        expect(json_response.first['title']).to eq(commit.title)
        expect(json_response.first['message']).to eq(commit.message)
        expect(json_response.first['author_name']).to eq(commit.author_name)
        expect(json_response.first['author_email']).to eq(commit.author_email)
        expect(json_response.first['committer_name']).to eq(commit.committer_name)
        expect(json_response.first['committer_email']).to eq(commit.committer_email)
      end

      context 'doesnt create when its already created' do
        before do
          create(:merge_request_context_commit, merge_request: merge_request, sha: commit.id)
        end
        it 'returns 400 when the context commit is already created' do
          post api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/context_commits", authenticated_user), params: params
          expect(response).to have_gitlab_http_status(400)
          expect(json_response['message']).to eq("Context commits: [\"#{commit.id}\"] are already created")
        end
      end

      it 'returns 400 when one or more shas are invalid' do
        post api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/context_commits", authenticated_user), params: params_invalid_shas
        expect(response).to have_gitlab_http_status(400)
        expect(json_response['message']).to eq('One or more context commits\' sha is not valid.')
      end

      it 'returns 400 when the commits are empty' do
        post api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/context_commits", authenticated_user), params: params_empty_commits
        expect(response).to have_gitlab_http_status(400)
      end

      it 'returns 400 when params is empty' do
        post api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/context_commits", authenticated_user)
        expect(response).to have_gitlab_http_status(400)
      end

      it 'returns 403 when creating new context commit for guest role' do
        guest = create(:user)
        project.add_guest(guest)
        post api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/context_commits", guest), params: params
        expect(response).to have_gitlab_http_status(403)
      end

      it 'returns 403 when creating new context commit for reporter role' do
        reporter = create(:user)
        project.add_reporter(reporter)
        post api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/context_commits", reporter), params: params
        expect(response).to have_gitlab_http_status(403)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401 if user tries to create context commits' do
        post api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/context_commits"), params: params
        expect(response).to have_gitlab_http_status(401)
      end
    end
  end

  describe "DELETE /projects/:id/merge_requests/:merge_request_iid" do
    context "when the user is developer" do
      let(:developer) { create(:user) }

      before do
        project.add_developer(developer)
      end

      it "denies the deletion of the merge request" do
        delete api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", developer)
        expect(response).to have_gitlab_http_status(403)
      end
    end

    context "when the user is project owner" do
      it "destroys the merge request owners can destroy" do
        delete api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user)

        expect(response).to have_gitlab_http_status(204)
      end

      it "returns 404 for an invalid merge request IID" do
        delete api("/projects/#{project.id}/merge_requests/12345", user)

        expect(response).to have_gitlab_http_status(404)
      end

      it "returns 404 if the merge request id is used instead of iid" do
        delete api("/projects/#{project.id}/merge_requests/#{merge_request.id}", user)

        expect(response).to have_gitlab_http_status(404)
      end

      it_behaves_like '412 response' do
        let(:request) { api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user) }
      end
    end
  end

  describe "DELETE /projects/:id/merge_requests/:merge_request_iid/context_commits" do
    let(:merge_request_iid)  { merge_request.iid }
    let(:authenticated_user) { user }
    let(:commit) { project.repository.commit }

    context "when authenticated" do
      let(:params) do
        {
          commits: [commit.id]
        }
      end

      let(:params_invalid_shas) do
        {
          commits: ["invalid"]
        }
      end

      let(:params_empty_commits) do
        {
          commits: []
        }
      end

      it "deletes context commit" do
        delete api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/context_commits", authenticated_user), params: params

        expect(response).to have_gitlab_http_status(204)
      end

      it "returns 400 when invalid commit sha is passed" do
        delete api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/context_commits", authenticated_user), params: params_invalid_shas

        expect(response).to have_gitlab_http_status(400)
        expect(json_response["message"]).to eq('One or more context commits\' sha is not valid.')
      end

      it "returns 400 when commits is empty" do
        delete api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/context_commits", authenticated_user), params: params_empty_commits

        expect(response).to have_gitlab_http_status(400)
      end

      it "returns 400 when no params is passed" do
        delete api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/context_commits", authenticated_user)

        expect(response).to have_gitlab_http_status(400)
      end

      it 'returns 403 when deleting existing context commit for guest role' do
        guest = create(:user)
        project.add_guest(guest)
        delete api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/context_commits", guest), params: params
        expect(response).to have_gitlab_http_status(403)
      end

      it 'returns 403 when deleting existing context commit for reporter role' do
        reporter = create(:user)
        project.add_reporter(reporter)
        delete api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/context_commits", reporter), params: params
        expect(response).to have_gitlab_http_status(403)
      end
    end

    context "when unauthenticated" do
      it "returns 401, unauthorised error" do
        delete api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/context_commits")

        expect(response).to have_gitlab_http_status(401)
      end
    end
  end

  describe "PUT /projects/:id/merge_requests/:merge_request_iid/merge", :clean_gitlab_redis_cache do
    let(:pipeline) { create(:ci_pipeline) }

    it "returns merge_request in case of success" do
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user)

      expect(response).to have_gitlab_http_status(200)
    end

    it "returns 406 if branch can't be merged" do
      allow_any_instance_of(MergeRequest)
        .to receive(:can_be_merged?).and_return(false)

      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user)

      expect(response).to have_gitlab_http_status(406)
      expect(json_response['message']).to eq('Branch cannot be merged')
    end

    it "returns 405 if merge_request is not open" do
      merge_request.close
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user)
      expect(response).to have_gitlab_http_status(405)
      expect(json_response['message']).to eq('405 Method Not Allowed')
    end

    it "returns 405 if merge_request is a work in progress" do
      merge_request.update_attribute(:title, "WIP: #{merge_request.title}")
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user)
      expect(response).to have_gitlab_http_status(405)
      expect(json_response['message']).to eq('405 Method Not Allowed')
    end

    it 'returns 405 if the build failed for a merge request that requires success' do
      project.update!(only_allow_merge_if_pipeline_succeeds: true)

      create(:ci_pipeline,
             :failed,
             sha: merge_request.diff_head_sha,
             merge_requests_as_head_pipeline: [merge_request])

      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user)

      expect(response).to have_gitlab_http_status(405)
      expect(json_response['message']).to eq('405 Method Not Allowed')
    end

    it "returns 401 if user has no permissions to merge" do
      user2 = create(:user)
      project.add_reporter(user2)
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user2)
      expect(response).to have_gitlab_http_status(401)
      expect(json_response['message']).to eq('401 Unauthorized')
    end

    it "returns 409 if the SHA parameter doesn't match" do
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user), params: { sha: merge_request.diff_head_sha.reverse }

      expect(response).to have_gitlab_http_status(409)
      expect(json_response['message']).to start_with('SHA does not match HEAD of source branch')
    end

    it "succeeds if the SHA parameter matches" do
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user), params: { sha: merge_request.diff_head_sha }

      expect(response).to have_gitlab_http_status(200)
    end

    it "updates the MR's squash attribute" do
      expect do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user), params: { squash: true }
      end.to change { merge_request.reload.squash }

      expect(response).to have_gitlab_http_status(200)
    end

    it 'does not merge if merge_when_pipeline_succeeds is passed and the pipeline has failed' do
      create(:ci_pipeline,
        :failed,
        sha: merge_request.diff_head_sha,
        merge_requests_as_head_pipeline: [merge_request])

      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user), params: { merge_when_pipeline_succeeds: true }

      expect(response).to have_gitlab_http_status(405)
      expect(merge_request.reload.state).to eq('opened')
    end

    it 'merges if the head pipeline already succeeded and `merge_when_pipeline_succeeds` is passed' do
      create(:ci_pipeline, :success, sha: merge_request.diff_head_sha, merge_requests_as_head_pipeline: [merge_request])

      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user), params: { merge_when_pipeline_succeeds: true }

      expect(response).to have_gitlab_http_status(200)
      expect(json_response['state']).to eq('merged')
    end

    it "enables merge when pipeline succeeds if the pipeline is active" do
      allow_any_instance_of(MergeRequest).to receive_messages(head_pipeline: pipeline, actual_head_pipeline: pipeline)
      allow(pipeline).to receive(:active?).and_return(true)

      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user), params: { merge_when_pipeline_succeeds: true }

      expect(response).to have_gitlab_http_status(200)
      expect(json_response['title']).to eq('Test')
      expect(json_response['merge_when_pipeline_succeeds']).to eq(true)
    end

    it "enables merge when pipeline succeeds if the pipeline is active and only_allow_merge_if_pipeline_succeeds is true" do
      allow_any_instance_of(MergeRequest).to receive_messages(head_pipeline: pipeline, actual_head_pipeline: pipeline)
      allow(pipeline).to receive(:active?).and_return(true)
      project.update_attribute(:only_allow_merge_if_pipeline_succeeds, true)

      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user), params: { merge_when_pipeline_succeeds: true }

      expect(response).to have_gitlab_http_status(200)
      expect(json_response['title']).to eq('Test')
      expect(json_response['merge_when_pipeline_succeeds']).to eq(true)
    end

    it "returns 404 for an invalid merge request IID" do
      put api("/projects/#{project.id}/merge_requests/12345/merge", user)

      expect(response).to have_gitlab_http_status(404)
    end

    it "returns 404 if the merge request id is used instead of iid" do
      put api("/projects/#{project.id}/merge_requests/#{merge_request.id}/merge", user)

      expect(response).to have_gitlab_http_status(404)
    end

    describe "the squash_commit_message param" do
      let(:squash_commit) do
        project.repository.commits_between(json_response['diff_refs']['start_sha'], json_response['merge_commit_sha']).first
      end

      it "results in a specific squash commit message when set" do
        squash_commit_message = 'My custom squash commit message'

        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user), params: {
          squash: true,
          squash_commit_message: squash_commit_message
        }

        expect(squash_commit.message.chomp).to eq(squash_commit_message)
      end

      it "results in a default squash commit message when not set" do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user), params: { squash: true }

        expect(squash_commit.message).to eq(merge_request.default_squash_commit_message)
      end
    end

    describe "the should_remove_source_branch param" do
      let(:source_repository) { merge_request.source_project.repository }
      let(:source_branch) { merge_request.source_branch }

      it 'removes the source branch when set' do
        put(
          api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user),
          params: { should_remove_source_branch: true }
        )

        expect(response).to have_gitlab_http_status(200)
        expect(source_repository.branch_exists?(source_branch)).to be_falsy
      end
    end

    context "performing a ff-merge with squash" do
      let(:merge_request) { create(:merge_request, :rebased, source_project: project, squash: true) }

      before do
        project.update(merge_requests_ff_only_enabled: true)
      end

      it "records the squash commit SHA and returns it in the response" do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user)

        expect(response).to have_gitlab_http_status(200)
        expect(json_response['squash_commit_sha'].length).to eq(40)
      end
    end
  end

  describe "GET /projects/:id/merge_requests/:merge_request_iid/merge_ref", :clean_gitlab_redis_shared_state do
    before do
      merge_request.mark_as_unchecked!
    end

    let(:merge_request_iid) { merge_request.iid }

    let(:url) do
      "/projects/#{project.id}/merge_requests/#{merge_request_iid}/merge_ref"
    end

    it 'returns the generated ID from the merge service in case of success' do
      get api(url, user)

      expect(response).to have_gitlab_http_status(200)
      expect(json_response['commit_id']).to eq(merge_request.merge_ref_head.sha)
    end

    context 'when merge-ref is not synced with merge status' do
      before do
        merge_request.update!(merge_status: 'cannot_be_merged')
      end

      it 'returns 200 if MR can be merged' do
        get api(url, user)

        expect(response).to have_gitlab_http_status(200)
        expect(json_response['commit_id']).to eq(merge_request.merge_ref_head.sha)
      end

      it 'returns 400 if MR cannot be merged' do
        expect_next_instance_of(MergeRequests::MergeToRefService) do |merge_request|
          expect(merge_request).to receive(:execute) { { status: :failed } }
        end

        get api(url, user)

        expect(response).to have_gitlab_http_status(400)
        expect(json_response['message']).to eq('Merge request is not mergeable')
      end
    end

    context 'when user has no access to the MR' do
      let(:project) { create(:project, :private) }
      let(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

      it 'returns 404' do
        project.add_guest(user)

        get api(url, user)

        expect(response).to have_gitlab_http_status(404)
        expect(json_response['message']).to eq('404 Not found')
      end
    end

    context 'when invalid merge request IID' do
      let(:merge_request_iid) { '12345' }

      it 'returns 404' do
        get api(url, user)

        expect(response).to have_gitlab_http_status(404)
      end
    end

    context 'when merge request ID is used instead IID' do
      let(:merge_request_iid) { merge_request.id }

      it 'returns 404' do
        get api(url, user)

        expect(response).to have_gitlab_http_status(404)
      end
    end
  end

  describe "PUT /projects/:id/merge_requests/:merge_request_iid" do
    context 'updates force_remove_source_branch properly' do
      it 'sets to false' do
        merge_request.update(merge_params: { 'force_remove_source_branch' => true } )

        expect(merge_request.force_remove_source_branch?).to be_truthy

        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: { state_event: "close", remove_source_branch: false }

        expect(response).to have_gitlab_http_status(200)
        expect(json_response['state']).to eq('closed')
        expect(json_response['force_remove_source_branch']).to be_falsey
      end

      it 'sets to true' do
        merge_request.update(merge_params: { 'force_remove_source_branch' => false } )

        expect(merge_request.force_remove_source_branch?).to be_falsey

        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: { state_event: "close", remove_source_branch: true }

        expect(response).to have_gitlab_http_status(200)
        expect(json_response['state']).to eq('closed')
        expect(json_response['force_remove_source_branch']).to be_truthy
      end

      context 'with a merge request across forks' do
        let(:fork_owner) { create(:user) }
        let(:source_project) { fork_project(project, fork_owner) }
        let(:target_project) { project }

        let(:merge_request) do
          create(:merge_request,
                 source_project: source_project,
                 target_project: target_project,
                 source_branch: 'fixes',
                 merge_params: { 'force_remove_source_branch' => false })
        end

        it 'is true for an authorized user' do
          put api("/projects/#{target_project.id}/merge_requests/#{merge_request.iid}", fork_owner), params: { state_event: 'close', remove_source_branch: true }

          expect(response).to have_gitlab_http_status(200)
          expect(json_response['state']).to eq('closed')
          expect(json_response['force_remove_source_branch']).to be true
        end

        it 'is false for an unauthorized user' do
          expect do
            put api("/projects/#{target_project.id}/merge_requests/#{merge_request.iid}", target_project.owner), params: { state_event: 'close', remove_source_branch: true }
          end.not_to change { merge_request.reload.merge_params }

          expect(response).to have_gitlab_http_status(200)
          expect(json_response['state']).to eq('closed')
          expect(json_response['force_remove_source_branch']).to be false
        end
      end
    end

    context "to close a MR" do
      it "returns merge_request" do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: { state_event: "close" }

        expect(response).to have_gitlab_http_status(200)
        expect(json_response['state']).to eq('closed')
      end
    end

    it "updates title and returns merge_request" do
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: { title: "New title" }
      expect(response).to have_gitlab_http_status(200)
      expect(json_response['title']).to eq('New title')
    end

    it "updates description and returns merge_request" do
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: { description: "New description" }
      expect(response).to have_gitlab_http_status(200)
      expect(json_response['description']).to eq('New description')
    end

    it "updates milestone_id and returns merge_request" do
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: { milestone_id: milestone.id }
      expect(response).to have_gitlab_http_status(200)
      expect(json_response['milestone']['id']).to eq(milestone.id)
    end

    it "updates squash and returns merge_request" do
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: { squash: true }

      expect(response).to have_gitlab_http_status(200)
      expect(json_response['squash']).to be_truthy
    end

    it "returns merge_request with renamed target_branch" do
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: { target_branch: "wiki" }
      expect(response).to have_gitlab_http_status(200)
      expect(json_response['target_branch']).to eq('wiki')
    end

    it "returns merge_request that removes the source branch" do
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: { remove_source_branch: true }

      expect(response).to have_gitlab_http_status(200)
      expect(json_response['force_remove_source_branch']).to be_truthy
    end

    it 'filters assignee_id of unauthorized user' do
      private_project = create(:project, :private, :repository)
      mr = create(:merge_request, source_project: private_project, target_project: private_project)
      another_user = create(:user)
      private_project.add_maintainer(user)
      params = { assignee_id: another_user.id }

      put api("/projects/#{private_project.id}/merge_requests/#{mr.iid}", user), params: params

      expect(response).to have_gitlab_http_status(200)
      expect(json_response['assignee']).to be_nil
    end

    context 'when updating labels' do
      it 'allows special label names' do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
          params: {
            title: 'new issue',
            labels: 'label, label?, label&foo, ?, &'
          }

        expect(response.status).to eq(200)
        expect(json_response['labels']).to include 'label'
        expect(json_response['labels']).to include 'label?'
        expect(json_response['labels']).to include 'label&foo'
        expect(json_response['labels']).to include '?'
        expect(json_response['labels']).to include '&'
      end

      it 'also accepts labels as an array' do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
          params: {
            title: 'new issue',
            labels: ['label', 'label?', 'label&foo, ?, &', '1, 2', 3, 4]
          }

        expect(response.status).to eq(200)
        expect(json_response['labels']).to include 'label'
        expect(json_response['labels']).to include 'label?'
        expect(json_response['labels']).to include 'label&foo'
        expect(json_response['labels']).to include '?'
        expect(json_response['labels']).to include '&'
        expect(json_response['labels']).to include '1'
        expect(json_response['labels']).to include '2'
        expect(json_response['labels']).to include '3'
        expect(json_response['labels']).to include '4'
      end

      it 'empty label param removes labels' do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
          params: {
            title: 'new issue',
            labels: ''
          }

        expect(response.status).to eq(200)
        expect(json_response['labels']).to eq []
      end

      it 'label param as empty array, but only explicitly as json, removes labels' do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
          params: {
            title: 'new issue',
            labels: []
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }

        expect(response.status).to eq(200)
        expect(json_response['labels']).to eq []
      end

      it 'empty label as array, removes labels' do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
          params: {
            title: 'new issue',
            labels: []
          }

        expect(response.status).to eq(200)
        expect(json_response['labels']).to eq []
      end

      it 'array with one empty string element removes labels' do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
          params: {
            title: 'new issue',
            labels: ['']
          }

        expect(response.status).to eq(200)
        expect(json_response['labels']).to eq []
      end

      it 'array with multiple empty string elements, removes labels' do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user),
          params: {
            title: 'new issue',
            labels: ['', '', '']
          }

        expect(response.status).to eq(200)
        expect(json_response['labels']).to eq []
      end
    end

    it 'does not update state when title is empty' do
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: { state_event: 'close', title: nil }

      merge_request.reload
      expect(response).to have_gitlab_http_status(400)
      expect(merge_request.state).to eq('opened')
    end

    it 'does not update state when target_branch is empty' do
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: { state_event: 'close', target_branch: nil }

      merge_request.reload
      expect(response).to have_gitlab_http_status(400)
      expect(merge_request.state).to eq('opened')
    end

    it "returns 404 for an invalid merge request IID" do
      put api("/projects/#{project.id}/merge_requests/12345", user), params: { state_event: "close" }

      expect(response).to have_gitlab_http_status(404)
    end

    it "returns 404 if the merge request id is used instead of iid" do
      put api("/projects/#{project.id}/merge_requests/#{merge_request.id}", user), params: { state_event: "close" }

      expect(response).to have_gitlab_http_status(404)
    end
  end

  describe 'GET :id/merge_requests/:merge_request_iid/closes_issues' do
    it 'returns the issue that will be closed on merge' do
      issue = create(:issue, project: project)
      mr = merge_request.tap do |mr|
        mr.update_attribute(:description, "Closes #{issue.to_reference(mr.project)}")
        mr.cache_merge_request_closes_issues!
      end

      get api("/projects/#{project.id}/merge_requests/#{mr.iid}/closes_issues", user)

      expect_successful_response_with_paginated_array
      expect(json_response.length).to eq(1)
      expect(json_response.first['id']).to eq(issue.id)
    end

    it 'returns an empty array when there are no issues to be closed' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/closes_issues", user)

      expect_empty_array_response
    end

    it 'handles external issues' do
      jira_project = create(:jira_project, :public, :repository, name: 'JIR_EXT1')
      ext_issue = ExternalIssue.new("#{jira_project.name}-123", jira_project)
      issue = create(:issue, project: jira_project)
      description = "Closes #{ext_issue.to_reference(jira_project)}\ncloses #{issue.to_reference}"
      merge_request = create(:merge_request,
        :simple, author: user, assignees: [user], source_project: jira_project, description: description)

      get api("/projects/#{jira_project.id}/merge_requests/#{merge_request.iid}/closes_issues", user)

      expect_successful_response_with_paginated_array
      expect(json_response.length).to eq(2)
      expect(json_response.second['title']).to eq(ext_issue.title)
      expect(json_response.second['id']).to eq(ext_issue.id)
      expect(json_response.second['confidential']).to be_nil
      expect(json_response.first['title']).to eq(issue.title)
      expect(json_response.first['id']).to eq(issue.id)
      expect(json_response.first['confidential']).not_to be_nil
    end

    it 'returns 403 if the user has no access to the merge request' do
      project = create(:project, :private)
      merge_request = create(:merge_request, :simple, source_project: project)
      guest = create(:user)
      project.add_guest(guest)

      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/closes_issues", guest)

      expect(response).to have_gitlab_http_status(403)
    end

    it "returns 404 for an invalid merge request IID" do
      get api("/projects/#{project.id}/merge_requests/12345/closes_issues", user)

      expect(response).to have_gitlab_http_status(404)
    end

    it "returns 404 if the merge request id is used instead of iid" do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.id}/closes_issues", user)

      expect(response).to have_gitlab_http_status(404)
    end
  end

  describe 'POST :id/merge_requests/:merge_request_iid/subscribe' do
    it 'subscribes to a merge request' do
      post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/subscribe", admin)

      expect(response).to have_gitlab_http_status(201)
      expect(json_response['subscribed']).to eq(true)
    end

    it 'returns 304 if already subscribed' do
      post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/subscribe", user)

      expect(response).to have_gitlab_http_status(304)
    end

    it 'returns 404 if the merge request is not found' do
      post api("/projects/#{project.id}/merge_requests/123/subscribe", user)

      expect(response).to have_gitlab_http_status(404)
    end

    it 'returns 404 if the merge request id is used instead of iid' do
      post api("/projects/#{project.id}/merge_requests/#{merge_request.id}/subscribe", user)

      expect(response).to have_gitlab_http_status(404)
    end

    it 'returns 403 if user has no access to read code' do
      guest = create(:user)
      project.add_guest(guest)

      post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/subscribe", guest)

      expect(response).to have_gitlab_http_status(403)
    end
  end

  describe 'POST :id/merge_requests/:merge_request_iid/unsubscribe' do
    it 'unsubscribes from a merge request' do
      post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/unsubscribe", user)

      expect(response).to have_gitlab_http_status(201)
      expect(json_response['subscribed']).to eq(false)
    end

    it 'returns 304 if not subscribed' do
      post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/unsubscribe", admin)

      expect(response).to have_gitlab_http_status(304)
    end

    it 'returns 404 if the merge request is not found' do
      post api("/projects/#{project.id}/merge_requests/123/unsubscribe", user)

      expect(response).to have_gitlab_http_status(404)
    end

    it 'returns 404 if the merge request id is used instead of iid' do
      post api("/projects/#{project.id}/merge_requests/#{merge_request.id}/unsubscribe", user)

      expect(response).to have_gitlab_http_status(404)
    end

    it 'returns 403 if user has no access to read code' do
      guest = create(:user)
      project.add_guest(guest)

      post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/unsubscribe", guest)

      expect(response).to have_gitlab_http_status(403)
    end
  end

  describe 'POST :id/merge_requests/:merge_request_iid/cancel_merge_when_pipeline_succeeds' do
    before do
      ::AutoMergeService.new(merge_request.target_project, user).execute(merge_request, AutoMergeService::STRATEGY_MERGE_WHEN_PIPELINE_SUCCEEDS)
    end

    it 'removes the merge_when_pipeline_succeeds status' do
      post api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/cancel_merge_when_pipeline_succeeds", user)

      expect(response).to have_gitlab_http_status(201)
    end

    it 'returns 404 if the merge request is not found' do
      post api("/projects/#{project.id}/merge_requests/123/cancel_merge_when_pipeline_succeeds", user)

      expect(response).to have_gitlab_http_status(404)
    end

    it 'returns 404 if the merge request id is used instead of iid' do
      post api("/projects/#{project.id}/merge_requests/#{merge_request.id}/cancel_merge_when_pipeline_succeeds", user)

      expect(response).to have_gitlab_http_status(404)
    end
  end

  describe 'PUT :id/merge_requests/:merge_request_iid/rebase' do
    context 'when rebase can be performed' do
      it 'enqueues a rebase of the merge request against the target branch' do
        Sidekiq::Testing.fake! do
          expect do
            put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/rebase", user)
          end.to change { RebaseWorker.jobs.size }.by(1)
        end

        expect(response).to have_gitlab_http_status(202)
        expect(merge_request.reload).to be_rebase_in_progress
        expect(json_response['rebase_in_progress']).to be(true)
      end

      context 'when skip_ci parameter is set' do
        it 'enqueues a rebase of the merge request with skip_ci flag set' do
          expect(RebaseWorker).to receive(:perform_async).with(merge_request.id, user.id, true).and_call_original

          Sidekiq::Testing.fake! do
            expect do
              put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/rebase", user), params: { skip_ci: true }
            end.to change { RebaseWorker.jobs.size }.by(1)
          end

          expect(response).to have_gitlab_http_status(202)
          expect(merge_request.reload).to be_rebase_in_progress
          expect(json_response['rebase_in_progress']).to be(true)
        end
      end
    end

    it 'returns 403 if the user cannot push to the branch' do
      guest = create(:user)
      project.add_guest(guest)

      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/rebase", guest)

      expect(response).to have_gitlab_http_status(403)
    end

    it 'returns 409 if a rebase is already in progress' do
      Sidekiq::Testing.fake! do
        merge_request.rebase_async(user.id)

        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/rebase", user)
      end

      expect(response).to have_gitlab_http_status(409)
    end

    it "returns 409 if rebase can't lock the row" do
      allow_any_instance_of(MergeRequest).to receive(:with_lock).and_raise(ActiveRecord::LockWaitTimeout)
      expect(RebaseWorker).not_to receive(:perform_async)

      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/rebase", user)

      expect(response).to have_gitlab_http_status(409)
      expect(json_response['message']).to eq('Failed to enqueue the rebase operation, possibly due to a long-lived transaction. Try again later.')
    end
  end

  describe 'Time tracking' do
    let(:issuable) { merge_request }

    include_examples 'time tracking endpoints', 'merge_request'
  end

  def mr_with_later_created_and_updated_at_time
    merge_request
    merge_request.created_at += 1.hour
    merge_request.updated_at += 30.minutes
    merge_request.save
    merge_request
  end

  def mr_with_earlier_created_and_updated_at_time
    merge_request_closed
    merge_request_closed.created_at -= 1.hour
    merge_request_closed.updated_at -= 30.minutes
    merge_request_closed.save
    merge_request_closed
  end
end
