# frozen_string_literal: true

require 'spec_helper'

describe Milestone, 'Milestoneish' do
  let(:author) { create(:user) }
  let(:assignee) { create(:user) }
  let(:non_member) { create(:user) }
  let(:member) { create(:user) }
  let(:guest) { create(:user) }
  let(:admin) { create(:admin) }
  let(:project) { create(:project, :public) }
  let(:milestone) { create(:milestone, project: project) }
  let(:label1) { create(:label, project: project) }
  let(:label2) { create(:label, project: project) }
  let!(:issue) { create(:issue, project: project, milestone: milestone, assignees: [member], labels: [label1]) }
  let!(:security_issue_1) { create(:issue, :confidential, project: project, author: author, milestone: milestone, labels: [label2]) }
  let!(:security_issue_2) { create(:issue, :confidential, project: project, assignees: [assignee], milestone: milestone) }
  let!(:closed_issue_1) { create(:issue, :closed, project: project, milestone: milestone) }
  let!(:closed_issue_2) { create(:issue, :closed, project: project, milestone: milestone) }
  let!(:closed_security_issue_1) { create(:issue, :confidential, :closed, project: project, author: author, milestone: milestone) }
  let!(:closed_security_issue_2) { create(:issue, :confidential, :closed, project: project, assignees: [assignee], milestone: milestone) }
  let!(:closed_security_issue_3) { create(:issue, :confidential, :closed, project: project, author: author, milestone: milestone) }
  let!(:closed_security_issue_4) { create(:issue, :confidential, :closed, project: project, assignees: [assignee], milestone: milestone) }
  let!(:merge_request) { create(:merge_request, source_project: project, target_project: project, milestone: milestone) }
  let(:label_1) { create(:label, title: 'label_1', project: project, priority: 1) }
  let(:label_2) { create(:label, title: 'label_2', project: project, priority: 2) }
  let(:label_3) { create(:label, title: 'label_3', project: project) }

  before do
    project.add_developer(member)
    project.add_guest(guest)
  end

  describe '#sorted_issues' do
    it 'sorts issues by label priority' do
      issue.labels << label_1
      security_issue_1.labels << label_2
      closed_issue_1.labels << label_3

      issues = milestone.sorted_issues(member)

      expect(issues.first).to eq(issue)
      expect(issues.second).to eq(security_issue_1)
      expect(issues.third).not_to eq(closed_issue_1)
    end
  end

  context 'attributes visibility' do
    using RSpec::Parameterized::TableSyntax

    let(:users) do
      {
        anonymous: nil,
        non_member: non_member,
        guest: guest,
        member: member,
        assignee: assignee
      }
    end

    let(:project_visibility_levels) do
      {
        public: Gitlab::VisibilityLevel::PUBLIC,
        internal: Gitlab::VisibilityLevel::INTERNAL,
        private: Gitlab::VisibilityLevel::PRIVATE
      }
    end

    describe '#issue_participants_visible_by_user' do
      where(:visibility, :user_role, :result) do
        :public   | nil         | [:member]
        :public   | :non_member | [:member]
        :public   | :guest      | [:member]
        :public   | :member     | [:member, :assignee]
        :internal | nil         | []
        :internal | :non_member | [:member]
        :internal | :guest      | [:member]
        :internal | :member     | [:member, :assignee]
        :private  | nil         | []
        :private  | :non_member | []
        :private  | :guest      | [:member]
        :private  | :member     | [:member, :assignee]
      end

      with_them do
        before do
          project.update(visibility_level: project_visibility_levels[visibility])
        end

        it 'returns the proper participants' do
          user = users[user_role]
          participants = result.map { |role| users[role] }

          expect(milestone.issue_participants_visible_by_user(user)).to match_array(participants)
        end
      end
    end

    describe '#issue_labels_visible_by_user' do
      let(:labels) do
        {
          label1: label1,
          label2: label2
        }
      end

      where(:visibility, :user_role, :result) do
        :public   | nil         | [:label1]
        :public   | :non_member | [:label1]
        :public   | :guest      | [:label1]
        :public   | :member     | [:label1, :label2]
        :internal | nil         | []
        :internal | :non_member | [:label1]
        :internal | :guest      | [:label1]
        :internal | :member     | [:label1, :label2]
        :private  | nil         | []
        :private  | :non_member | []
        :private  | :guest      | [:label1]
        :private  | :member     | [:label1, :label2]
      end

      with_them do
        before do
          project.update(visibility_level: project_visibility_levels[visibility])
        end

        it 'returns the proper participants' do
          user = users[user_role]
          expected_labels = result.map { |label| labels[label] }

          expect(milestone.issue_labels_visible_by_user(user)).to match_array(expected_labels)
        end
      end
    end
  end

  describe '#sorted_merge_requests' do
    it 'sorts merge requests by label priority' do
      merge_request_1 = create(:labeled_merge_request, labels: [label_2], source_project: project, source_branch: 'branch_1', milestone: milestone)
      merge_request_2 = create(:labeled_merge_request, labels: [label_1], source_project: project, source_branch: 'branch_2', milestone: milestone)
      merge_request_3 = create(:labeled_merge_request, labels: [label_3], source_project: project, source_branch: 'branch_3', milestone: milestone)

      merge_requests = milestone.sorted_merge_requests(member)

      expect(merge_requests.first).to eq(merge_request_2)
      expect(merge_requests.second).to eq(merge_request_1)
      expect(merge_requests.third).to eq(merge_request_3)
    end
  end

  describe '#merge_requests_visible_to_user' do
    let(:merge_request) { create(:merge_request, source_project: project, milestone: milestone) }

    context 'when project is private' do
      before do
        project.update(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
      end

      it 'does not return any merge request for a non member' do
        merge_requests = milestone.merge_requests_visible_to_user(non_member)
        expect(merge_requests).to be_empty
      end

      it 'returns milestone merge requests for a member' do
        merge_requests = milestone.merge_requests_visible_to_user(member)
        expect(merge_requests).to contain_exactly(merge_request)
      end
    end

    context 'when project is public' do
      context 'when merge requests are available to anyone' do
        it 'returns milestone merge requests for a non member' do
          merge_requests = milestone.merge_requests_visible_to_user(non_member)
          expect(merge_requests).to contain_exactly(merge_request)
        end
      end

      context 'when merge requests are available to project members' do
        before do
          project.project_feature.update(merge_requests_access_level: ProjectFeature::PRIVATE)
        end

        it 'does not return any merge request for a non member' do
          merge_requests = milestone.merge_requests_visible_to_user(non_member)
          expect(merge_requests).to be_empty
        end

        it 'returns milestone merge requests for a member' do
          merge_requests = milestone.merge_requests_visible_to_user(member)
          expect(merge_requests).to contain_exactly(merge_request)
        end
      end
    end
  end

  describe '#closed_items_count' do
    it 'does not count confidential issues for non project members' do
      expect(milestone.closed_items_count(non_member)).to eq 2
    end

    it 'does not count confidential issues for project members with guest role' do
      expect(milestone.closed_items_count(guest)).to eq 2
    end

    it 'counts confidential issues for author' do
      expect(milestone.closed_items_count(author)).to eq 4
    end

    it 'counts confidential issues for assignee' do
      expect(milestone.closed_items_count(assignee)).to eq 4
    end

    it 'counts confidential issues for project members' do
      expect(milestone.closed_items_count(member)).to eq 6
    end

    it 'counts all issues for admin' do
      expect(milestone.closed_items_count(admin)).to eq 6
    end
  end

  describe '#total_items_count' do
    it 'does not count confidential issues for non project members' do
      expect(milestone.total_items_count(non_member)).to eq 4
    end

    it 'does not count confidential issues for project members with guest role' do
      expect(milestone.total_items_count(guest)).to eq 4
    end

    it 'counts confidential issues for author' do
      expect(milestone.total_items_count(author)).to eq 7
    end

    it 'counts confidential issues for assignee' do
      expect(milestone.total_items_count(assignee)).to eq 7
    end

    it 'counts confidential issues for project members' do
      expect(milestone.total_items_count(member)).to eq 10
    end

    it 'counts all issues for admin' do
      expect(milestone.total_items_count(admin)).to eq 10
    end
  end

  describe '#complete?' do
    it 'returns false when has items opened' do
      expect(milestone.complete?(non_member)).to eq false
    end

    it 'returns true when all items are closed' do
      issue.close
      merge_request.close

      expect(milestone.complete?(non_member)).to eq true
    end
  end

  describe '#percent_complete' do
    it 'does not count confidential issues for non project members' do
      expect(milestone.percent_complete(non_member)).to eq 50
    end

    it 'does not count confidential issues for project members with guest role' do
      expect(milestone.percent_complete(guest)).to eq 50
    end

    it 'counts confidential issues for author' do
      expect(milestone.percent_complete(author)).to eq 57
    end

    it 'counts confidential issues for assignee' do
      expect(milestone.percent_complete(assignee)).to eq 57
    end

    it 'counts confidential issues for project members' do
      expect(milestone.percent_complete(member)).to eq 60
    end

    it 'counts confidential issues for admin' do
      expect(milestone.percent_complete(admin)).to eq 60
    end
  end

  describe '#remaining_days' do
    it 'shows 0 if no due date' do
      milestone = build_stubbed(:milestone)

      expect(milestone.remaining_days).to eq(0)
    end

    it 'shows 0 if expired' do
      milestone = build_stubbed(:milestone, due_date: 2.days.ago)

      expect(milestone.remaining_days).to eq(0)
    end

    it 'shows correct remaining days' do
      milestone = build_stubbed(:milestone, due_date: 2.days.from_now)

      expect(milestone.remaining_days).to eq(2)
    end
  end

  describe '#elapsed_days' do
    it 'shows 0 if no start_date set' do
      milestone = build_stubbed(:milestone)

      expect(milestone.elapsed_days).to eq(0)
    end

    it 'shows 0 if start_date is a future' do
      milestone = build_stubbed(:milestone, start_date: Time.now + 2.days)

      expect(milestone.elapsed_days).to eq(0)
    end

    it 'shows correct amount of days' do
      milestone = build_stubbed(:milestone, start_date: Time.now - 2.days)

      expect(milestone.elapsed_days).to eq(2)
    end
  end

  describe '#total_issue_time_spent' do
    it 'calculates total issue time spent' do
      closed_issue_1.spend_time(duration: 300, user_id: author.id)
      closed_issue_1.save!
      closed_issue_2.spend_time(duration: 600, user_id: assignee.id)
      closed_issue_2.save!

      expect(milestone.total_issue_time_spent).to eq(900)
    end
  end

  describe '#human_total_issue_time_spent' do
    it 'returns nil if no time has been spent' do
      expect(milestone.human_total_issue_time_spent).to be_nil
    end
  end
end
