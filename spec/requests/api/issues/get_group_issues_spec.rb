# frozen_string_literal: true

require 'spec_helper'

describe API::Issues do
  set(:user) { create(:user) }
  let(:user2)       { create(:user) }
  let(:non_member)  { create(:user) }
  set(:guest)       { create(:user) }
  set(:author)      { create(:author) }
  set(:assignee)    { create(:assignee) }
  let(:admin)       { create(:user, :admin) }

  let(:issue_title)       { 'foo' }
  let(:issue_description) { 'closed' }

  let(:no_milestone_title) { 'None' }
  let(:any_milestone_title) { 'Any' }

  before do
    stub_licensed_features(multiple_issue_assignees: false, issue_weights: false)
  end

  describe 'GET /groups/:id/issues' do
    let!(:group)            { create(:group) }
    let!(:group_project)    { create(:project, :public, creator_id: user.id, namespace: group) }
    let!(:group_closed_issue) do
      create :closed_issue,
        author: user,
        assignees: [user],
        project: group_project,
        state: :closed,
        milestone: group_milestone,
        updated_at: 3.hours.ago,
        created_at: 1.day.ago
    end
    let!(:group_confidential_issue) do
      create :issue,
        :confidential,
        project: group_project,
        author: author,
        assignees: [assignee],
        updated_at: 2.hours.ago,
        created_at: 2.days.ago
    end
    let!(:group_issue) do
      create :issue,
        author: user,
        assignees: [user],
        project: group_project,
        milestone: group_milestone,
        updated_at: 1.hour.ago,
        title: issue_title,
        description: issue_description,
        created_at: 5.days.ago
    end
    let!(:group_label) do
      create(:label, title: 'group_lbl', color: '#FFAABB', project: group_project)
    end
    let!(:group_label_link) { create(:label_link, label: group_label, target: group_issue) }
    let!(:group_milestone) { create(:milestone, title: '3.0.0', project: group_project) }
    let!(:group_empty_milestone) do
      create(:milestone, title: '4.0.0', project: group_project)
    end
    let!(:group_note) { create(:note_on_issue, author: user, project: group_project, noteable: group_issue) }

    let(:base_url) { "/groups/#{group.id}/issues" }

    shared_examples 'group issues statistics' do
      it 'returns issues statistics' do
        get api("/groups/#{group.id}/issues_statistics", user), params: params

        expect(response).to have_gitlab_http_status(200)
        expect(json_response['statistics']).not_to be_nil
        expect(json_response['statistics']['counts']['all']).to eq counts[:all]
        expect(json_response['statistics']['counts']['closed']).to eq counts[:closed]
        expect(json_response['statistics']['counts']['opened']).to eq counts[:opened]
      end
    end

    context 'when group has subgroups', :nested_groups do
      let(:subgroup_1) { create(:group, parent: group) }
      let(:subgroup_2) { create(:group, parent: subgroup_1) }

      let(:subgroup_1_project) { create(:project, :public, namespace: subgroup_1) }
      let(:subgroup_2_project) { create(:project, namespace: subgroup_2) }

      let!(:issue_1) { create(:issue, project: subgroup_1_project) }
      let!(:issue_2) { create(:issue, project: subgroup_2_project) }

      context 'when user is unauthenticated' do
        it 'also returns subgroups public projects issues' do
          get api(base_url)

          expect_paginated_array_response([issue_1.id, group_closed_issue.id, group_issue.id])
        end

        it 'also returns subgroups public projects issues filtered by milestone' do
          get api(base_url), params: { milestone: group_milestone.title }

          expect_paginated_array_response([group_closed_issue.id, group_issue.id])
        end

        context 'issues_statistics' do
          context 'no state is treated as all state' do
            let(:params) { {} }
            let(:counts) { { all: 3, closed: 1, opened: 2 } }

            it_behaves_like 'group issues statistics'
          end

          context 'statistics when all state is passed' do
            let(:params) { { state: :all } }
            let(:counts) { { all: 3, closed: 1, opened: 2 } }

            it_behaves_like 'group issues statistics'
          end

          context 'closed state is treated as all state' do
            let(:params) { { state: :closed } }
            let(:counts) { { all: 3, closed: 1, opened: 2 } }

            it_behaves_like 'group issues statistics'
          end

          context 'opened state is treated as all state' do
            let(:params) { { state: :opened } }
            let(:counts) { { all: 3, closed: 1, opened: 2 } }

            it_behaves_like 'group issues statistics'
          end

          context 'when filtering by milestone and no state treated as all state' do
            let(:params) { { milestone: group_milestone.title } }
            let(:counts) { { all: 2, closed: 1, opened: 1 } }

            it_behaves_like 'group issues statistics'
          end

          context 'when filtering by milestone and all state' do
            let(:params) { { milestone: group_milestone.title, state: :all } }
            let(:counts) { { all: 2, closed: 1, opened: 1 } }

            it_behaves_like 'group issues statistics'
          end

          context 'when filtering by milestone and closed state treated as all state' do
            let(:params) { { milestone: group_milestone.title, state: :closed } }
            let(:counts) { { all: 2, closed: 1, opened: 1 } }

            it_behaves_like 'group issues statistics'
          end

          context 'when filtering by milestone and opened state treated as all state' do
            let(:params) { { milestone: group_milestone.title, state: :opened } }
            let(:counts) { { all: 2, closed: 1, opened: 1 } }

            it_behaves_like 'group issues statistics'
          end
        end
      end

      context 'when user is a group member' do
        before do
          group.add_developer(user)
        end

        it 'also returns subgroups projects issues' do
          get api(base_url, user)

          expect_paginated_array_response([issue_2.id, issue_1.id, group_closed_issue.id, group_confidential_issue.id, group_issue.id])
        end

        it 'also returns subgroups public projects issues filtered by milestone' do
          get api(base_url, user), params: { milestone: group_milestone.title }

          expect_paginated_array_response([group_closed_issue.id, group_issue.id])
        end

        context 'issues_statistics' do
          context 'no state is treated as all state' do
            let(:params) { {} }
            let(:counts) { { all: 5, closed: 1, opened: 4 } }

            it_behaves_like 'group issues statistics'
          end

          context 'statistics when all state is passed' do
            let(:params) { { state: :all } }
            let(:counts) { { all: 5, closed: 1, opened: 4 } }

            it_behaves_like 'group issues statistics'
          end

          context 'closed state is treated as all state' do
            let(:params) { { state: :closed } }
            let(:counts) { { all: 5, closed: 1, opened: 4 } }

            it_behaves_like 'group issues statistics'
          end

          context 'opened state is treated as all state' do
            let(:params) { { state: :opened } }
            let(:counts) { { all: 5, closed: 1, opened: 4 } }

            it_behaves_like 'group issues statistics'
          end

          context 'when filtering by milestone and no state treated as all state' do
            let(:params) { { milestone: group_milestone.title } }
            let(:counts) { { all: 2, closed: 1, opened: 1 } }

            it_behaves_like 'group issues statistics'
          end

          context 'when filtering by milestone and all state' do
            let(:params) { { milestone: group_milestone.title, state: :all } }
            let(:counts) { { all: 2, closed: 1, opened: 1 } }

            it_behaves_like 'group issues statistics'
          end

          context 'when filtering by milestone and closed state treated as all state' do
            let(:params) { { milestone: group_milestone.title, state: :closed } }
            let(:counts) { { all: 2, closed: 1, opened: 1 } }

            it_behaves_like 'group issues statistics'
          end

          context 'when filtering by milestone and opened state treated as all state' do
            let(:params) { { milestone: group_milestone.title, state: :opened } }
            let(:counts) { { all: 2, closed: 1, opened: 1 } }

            it_behaves_like 'group issues statistics'
          end
        end
      end
    end

    context 'when user is unauthenticated' do
      it 'lists all issues in public projects' do
        get api(base_url)

        expect_paginated_array_response([group_closed_issue.id, group_issue.id])
      end

      it 'also returns subgroups public projects issues filtered by milestone' do
        get api(base_url), params: { milestone: group_milestone.title }

        expect_paginated_array_response([group_closed_issue.id, group_issue.id])
      end

      context 'issues_statistics' do
        context 'no state is treated as all state' do
          let(:params) { {} }
          let(:counts) { { all: 2, closed: 1, opened: 1 } }

          it_behaves_like 'group issues statistics'
        end

        context 'statistics when all state is passed' do
          let(:params) { { state: :all } }
          let(:counts) { { all: 2, closed: 1, opened: 1 } }

          it_behaves_like 'group issues statistics'
        end

        context 'closed state is treated as all state' do
          let(:params) { { state: :closed } }
          let(:counts) { { all: 2, closed: 1, opened: 1 } }

          it_behaves_like 'group issues statistics'
        end

        context 'opened state is treated as all state' do
          let(:params) { { state: :opened } }
          let(:counts) { { all: 2, closed: 1, opened: 1 } }

          it_behaves_like 'group issues statistics'
        end

        context 'when filtering by milestone and no state treated as all state' do
          let(:params) { { milestone: group_milestone.title } }
          let(:counts) { { all: 2, closed: 1, opened: 1 } }

          it_behaves_like 'group issues statistics'
        end

        context 'when filtering by milestone and all state' do
          let(:params) { { milestone: group_milestone.title, state: :all } }
          let(:counts) { { all: 2, closed: 1, opened: 1 } }

          it_behaves_like 'group issues statistics'
        end

        context 'when filtering by milestone and closed state treated as all state' do
          let(:params) { { milestone: group_milestone.title, state: :closed } }
          let(:counts) { { all: 2, closed: 1, opened: 1 } }

          it_behaves_like 'group issues statistics'
        end

        context 'when filtering by milestone and opened state treated as all state' do
          let(:params) { { milestone: group_milestone.title, state: :opened } }
          let(:counts) { { all: 2, closed: 1, opened: 1 } }

          it_behaves_like 'group issues statistics'
        end
      end
    end

    context 'when user is a group member' do
      before do
        group_project.add_reporter(user)
      end

      it 'returns all group issues (including opened and closed)' do
        get api(base_url, admin)

        expect_paginated_array_response([group_closed_issue.id, group_confidential_issue.id, group_issue.id])
      end

      it 'returns group issues without confidential issues for non project members' do
        get api(base_url, non_member), params: { state: :opened }

        expect_paginated_array_response(group_issue.id)
      end

      it 'returns group confidential issues for author' do
        get api(base_url, author), params: { state: :opened }

        expect_paginated_array_response([group_confidential_issue.id, group_issue.id])
      end

      it 'returns group confidential issues for assignee' do
        get api(base_url, assignee), params: { state: :opened }

        expect_paginated_array_response([group_confidential_issue.id, group_issue.id])
      end

      it 'returns group issues with confidential issues for project members' do
        get api(base_url, user), params: { state: :opened }

        expect_paginated_array_response([group_confidential_issue.id, group_issue.id])
      end

      it 'returns group confidential issues for admin' do
        get api(base_url, admin), params: { state: :opened }

        expect_paginated_array_response([group_confidential_issue.id, group_issue.id])
      end

      it 'returns only confidential issues' do
        get api(base_url, user), params: { confidential: true }

        expect_paginated_array_response(group_confidential_issue.id)
      end

      it 'returns only public issues' do
        get api(base_url, user), params: { confidential: false }

        expect_paginated_array_response([group_closed_issue.id, group_issue.id])
      end

      it 'returns an array of labeled group issues' do
        get api(base_url, user), params: { labels: group_label.title }

        expect_paginated_array_response(group_issue.id)
        expect(json_response.first['labels']).to eq([group_label.title])
      end

      it 'returns an array of labeled group issues with labels param as array' do
        get api(base_url, user), params: { labels: [group_label.title] }

        expect_paginated_array_response(group_issue.id)
        expect(json_response.first['labels']).to eq([group_label.title])
      end

      it 'returns an array of labeled group issues where all labels match' do
        get api(base_url, user), params: { labels: "#{group_label.title},foo,bar" }

        expect_paginated_array_response([])
      end

      it 'returns an array of labeled group issues where all labels match with labels param as array' do
        get api(base_url, user), params: { labels: [group_label.title, 'foo', 'bar'] }

        expect_paginated_array_response([])
      end

      it 'returns issues matching given search string for title' do
        get api(base_url, user), params: { search: group_issue.title }

        expect_paginated_array_response(group_issue.id)
      end

      it 'returns issues matching given search string for description' do
        get api(base_url, user), params: { search: group_issue.description }

        expect_paginated_array_response(group_issue.id)
      end

      context 'with labeled issues' do
        let(:label_b) { create(:label, title: 'foo', project: group_project) }
        let(:label_c) { create(:label, title: 'bar', project: group_project) }

        before do
          create(:label_link, label: label_b, target: group_issue)
          create(:label_link, label: label_c, target: group_issue)

          get api(base_url, user), params: params
        end

        let(:issue) { group_issue }
        let(:label) { group_label }

        it_behaves_like 'labeled issues with labels and label_name params'
      end

      it 'returns an array of issues found by iids' do
        get api(base_url, user), params: { iids: [group_issue.iid] }

        expect_paginated_array_response(group_issue.id)
        expect(json_response.first['id']).to eq(group_issue.id)
      end

      it 'returns an empty array if iid does not exist' do
        get api(base_url, user), params: { iids: [0] }

        expect_paginated_array_response([])
      end

      it 'returns an empty array if no group issue matches labels' do
        get api(base_url, user), params: { labels: 'foo,bar' }

        expect_paginated_array_response([])
      end

      it 'returns an array of group issues with any label' do
        get api(base_url, user), params: { labels: IssuesFinder::FILTER_ANY }

        expect_paginated_array_response(group_issue.id)
        expect(json_response.first['id']).to eq(group_issue.id)
      end

      it 'returns an array of group issues with any label with labels param as array' do
        get api(base_url, user), params: { labels: [IssuesFinder::FILTER_ANY] }

        expect_paginated_array_response(group_issue.id)
        expect(json_response.first['id']).to eq(group_issue.id)
      end

      it 'returns an array of group issues with no label' do
        get api(base_url, user), params: { labels: IssuesFinder::FILTER_NONE }

        expect_paginated_array_response([group_closed_issue.id, group_confidential_issue.id])
      end

      it 'returns an array of group issues with no label with labels param as array' do
        get api(base_url, user), params: { labels: [IssuesFinder::FILTER_NONE] }

        expect_paginated_array_response([group_closed_issue.id, group_confidential_issue.id])
      end

      it 'returns an empty array if no issue matches milestone' do
        get api(base_url, user), params: { milestone: group_empty_milestone.title }

        expect_paginated_array_response([])
      end

      it 'returns an empty array if milestone does not exist' do
        get api(base_url, user), params: { milestone: 'foo' }

        expect_paginated_array_response([])
      end

      it 'returns an array of issues in given milestone' do
        get api(base_url, user), params: { state: :opened, milestone: group_milestone.title }

        expect_paginated_array_response(group_issue.id)
      end

      it 'returns an array of issues matching state in milestone' do
        get api(base_url, user), params: { milestone: group_milestone.title, state: :closed }

        expect_paginated_array_response(group_closed_issue.id)
      end

      it 'returns an array of issues with no milestone' do
        get api(base_url, user), params: { milestone: no_milestone_title }

        expect(response).to have_gitlab_http_status(200)

        expect_paginated_array_response(group_confidential_issue.id)
      end

      context 'without sort params' do
        it 'sorts by created_at descending by default' do
          get api(base_url, user)

          expect_paginated_array_response([group_closed_issue.id, group_confidential_issue.id, group_issue.id])
        end

        context 'with 2 issues with same created_at' do
          let!(:group_issue2) do
            create :issue,
              author: user,
              assignees: [user],
              project: group_project,
              milestone: group_milestone,
              updated_at: 1.hour.ago,
              title: issue_title,
              description: issue_description,
              created_at: group_issue.created_at
          end

          it 'page breaks first page correctly' do
            get api("#{base_url}?per_page=3", user)

            expect_paginated_array_response([group_closed_issue.id, group_confidential_issue.id, group_issue2.id])
          end

          it 'page breaks second page correctly' do
            get api("#{base_url}?per_page=3&page=2", user)

            expect_paginated_array_response([group_issue.id])
          end
        end
      end

      it 'sorts ascending when requested' do
        get api("#{base_url}?sort=asc", user)

        expect_paginated_array_response([group_issue.id, group_confidential_issue.id, group_closed_issue.id])
      end

      it 'sorts by updated_at descending when requested' do
        get api("#{base_url}?order_by=updated_at", user)

        group_issue.touch(:updated_at)

        expect_paginated_array_response([group_issue.id, group_confidential_issue.id, group_closed_issue.id])
      end

      it 'sorts by updated_at ascending when requested' do
        get api(base_url, user), params: { order_by: :updated_at, sort: :asc }

        expect_paginated_array_response([group_closed_issue.id, group_confidential_issue.id, group_issue.id])
      end

      context 'issues_statistics' do
        context 'no state is treated as all state' do
          let(:params) { {} }
          let(:counts) { { all: 3, closed: 1, opened: 2 } }

          it_behaves_like 'group issues statistics'
        end

        context 'statistics when all state is passed' do
          let(:params) { { state: :all } }
          let(:counts) { { all: 3, closed: 1, opened: 2 } }

          it_behaves_like 'group issues statistics'
        end

        context 'closed state is treated as all state' do
          let(:params) { { state: :closed } }
          let(:counts) { { all: 3, closed: 1, opened: 2 } }

          it_behaves_like 'group issues statistics'
        end

        context 'opened state is treated as all state' do
          let(:params) { { state: :opened } }
          let(:counts) { { all: 3, closed: 1, opened: 2 } }

          it_behaves_like 'group issues statistics'
        end

        context 'when filtering by milestone and no state treated as all state' do
          let(:params) { { milestone: group_milestone.title } }
          let(:counts) { { all: 2, closed: 1, opened: 1 } }

          it_behaves_like 'group issues statistics'
        end

        context 'when filtering by milestone and all state' do
          let(:params) { { milestone: group_milestone.title, state: :all } }
          let(:counts) { { all: 2, closed: 1, opened: 1 } }

          it_behaves_like 'group issues statistics'
        end

        context 'when filtering by milestone and closed state treated as all state' do
          let(:params) { { milestone: group_milestone.title, state: :closed } }
          let(:counts) { { all: 2, closed: 1, opened: 1 } }

          it_behaves_like 'group issues statistics'
        end

        context 'when filtering by milestone and opened state treated as all state' do
          let(:params) { { milestone: group_milestone.title, state: :opened } }
          let(:counts) { { all: 2, closed: 1, opened: 1 } }

          it_behaves_like 'group issues statistics'
        end

        context 'sort does not affect statistics ' do
          let(:params) { { state: :opened, order_by: 'updated_at' } }
          let(:counts) { { all: 3, closed: 1, opened: 2 } }

          it_behaves_like 'group issues statistics'
        end
      end

      context 'filtering by assignee_username' do
        let(:another_assignee) { create(:assignee) }
        let!(:issue1) { create(:issue, author: user2, project: group_project, created_at: 3.days.ago) }
        let!(:issue2) { create(:issue, author: user2, project: group_project, created_at: 2.days.ago) }
        let!(:issue3) { create(:issue, author: user2, assignees: [assignee, another_assignee], project: group_project, created_at: 1.day.ago) }

        it 'returns issues with by assignee_username' do
          get api(base_url, user), params: { assignee_username: [assignee.username], scope: 'all' }

          expect(issue3.reload.assignees.pluck(:id)).to match_array([assignee.id, another_assignee.id])
          expect_paginated_array_response([issue3.id, group_confidential_issue.id])
        end

        it 'returns issues by assignee_username as string' do
          get api(base_url, user), params: { assignee_username: assignee.username, scope: 'all' }

          expect(issue3.reload.assignees.pluck(:id)).to match_array([assignee.id, another_assignee.id])
          expect_paginated_array_response([issue3.id, group_confidential_issue.id])
        end

        it 'returns error when multiple assignees are passed' do
          get api(base_url, user), params: { assignee_username: [assignee.username, another_assignee.username], scope: 'all' }

          expect(response).to have_gitlab_http_status(400)
          expect(json_response["error"]).to include("allows one value, but found 2")
        end

        it 'returns error when assignee_username and assignee_id are passed together' do
          get api(base_url, user), params: { assignee_username: [assignee.username], assignee_id: another_assignee.id, scope: 'all' }

          expect(response).to have_gitlab_http_status(400)
          expect(json_response["error"]).to include("mutually exclusive")
        end
      end
    end
  end
end
