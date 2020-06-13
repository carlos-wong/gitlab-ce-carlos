# frozen_string_literal: true

require 'spec_helper'

describe Issues::CloseService do
  let(:project) { create(:project, :repository) }
  let(:user) { create(:user, email: "user@example.com") }
  let(:user2) { create(:user, email: "user2@example.com") }
  let(:guest) { create(:user) }
  let(:issue) { create(:issue, title: "My issue", project: project, assignees: [user2], author: create(:user)) }
  let(:external_issue) { ExternalIssue.new('JIRA-123', project) }
  let(:closing_merge_request) { create(:merge_request, source_project: project) }
  let(:closing_commit) { create(:commit, project: project) }
  let!(:todo) { create(:todo, :assigned, user: user, project: project, target: issue, author: user2) }

  before do
    project.add_maintainer(user)
    project.add_developer(user2)
    project.add_guest(guest)
  end

  describe '#execute' do
    let(:service) { described_class.new(project, user) }

    it 'checks if the user is authorized to update the issue' do
      expect(service).to receive(:can?).with(user, :update_issue, issue)
        .and_call_original

      service.execute(issue)
    end

    it 'does not close the issue when the user is not authorized to do so' do
      allow(service).to receive(:can?).with(user, :update_issue, issue)
        .and_return(false)

      expect(service).not_to receive(:close_issue)
      expect(service.execute(issue)).to eq(issue)
    end

    it 'closes the external issue even when the user is not authorized to do so' do
      allow(service).to receive(:can?).with(user, :update_issue, external_issue)
        .and_return(false)

      expect(service).to receive(:close_issue)
        .with(external_issue, closed_via: nil, notifications: true, system_note: true)

      service.execute(external_issue)
    end

    it 'closes the issue when the user is authorized to do so' do
      allow(service).to receive(:can?).with(user, :update_issue, issue)
        .and_return(true)

      expect(service).to receive(:close_issue)
        .with(issue, closed_via: nil, notifications: true, system_note: true)

      service.execute(issue)
    end

    it 'refreshes the number of open issues', :use_clean_rails_memory_store_caching do
      expect { service.execute(issue) }
        .to change { project.open_issues_count }.from(1).to(0)
    end

    it 'invalidates counter cache for assignees' do
      expect_any_instance_of(User).to receive(:invalidate_issue_cache_counts)

      service.execute(issue)
    end
  end

  describe '#close_issue' do
    context 'with external issue' do
      context 'with an active external issue tracker supporting close_issue' do
        let!(:external_issue_tracker) { create(:jira_service, project: project) }

        it 'closes the issue on the external issue tracker' do
          expect(project.external_issue_tracker).to receive(:close_issue)

          described_class.new(project, user).close_issue(external_issue)
        end
      end

      context 'with innactive external issue tracker supporting close_issue' do
        let!(:external_issue_tracker) { create(:jira_service, project: project, active: false) }

        it 'does not close the issue on the external issue tracker' do
          expect(project.external_issue_tracker).not_to receive(:close_issue)

          described_class.new(project, user).close_issue(external_issue)
        end
      end

      context 'with an active external issue tracker not supporting close_issue' do
        let!(:external_issue_tracker) { create(:bugzilla_service, project: project) }

        it 'does not close the issue on the external issue tracker' do
          expect(project.external_issue_tracker).not_to receive(:close_issue)

          described_class.new(project, user).close_issue(external_issue)
        end
      end
    end

    context "closed by a merge request", :sidekiq_might_not_need_inline do
      it 'mentions closure via a merge request' do
        perform_enqueued_jobs do
          described_class.new(project, user).close_issue(issue, closed_via: closing_merge_request)
        end

        email = ActionMailer::Base.deliveries.last

        expect(email.to.first).to eq(user2.email)
        expect(email.subject).to include(issue.title)
        expect(email.body.parts.map(&:body)).to all(include(closing_merge_request.to_reference))
      end

      context 'when user cannot read merge request' do
        it 'does not mention merge request' do
          project.project_feature.update_attribute(:repository_access_level, ProjectFeature::DISABLED)
          perform_enqueued_jobs do
            described_class.new(project, user).close_issue(issue, closed_via: closing_merge_request)
          end

          email = ActionMailer::Base.deliveries.last
          body_text = email.body.parts.map(&:body).join(" ")

          expect(email.to.first).to eq(user2.email)
          expect(email.subject).to include(issue.title)
          expect(body_text).not_to include(closing_merge_request.to_reference)
        end
      end

      context 'updating `metrics.first_mentioned_in_commit_at`' do
        subject { described_class.new(project, user).close_issue(issue, closed_via: closing_merge_request) }

        context 'when `metrics.first_mentioned_in_commit_at` is not set' do
          it 'uses the first commit authored timestamp' do
            expected = closing_merge_request.commits.first.authored_date

            subject

            expect(issue.metrics.first_mentioned_in_commit_at).to eq(expected)
          end
        end

        context 'when `metrics.first_mentioned_in_commit_at` is already set' do
          before do
            issue.metrics.update!(first_mentioned_in_commit_at: Time.now)
          end

          it 'does not update the metrics' do
            expect { subject }.not_to change { issue.metrics.first_mentioned_in_commit_at }
          end
        end

        context 'when merge request has no commits' do
          let(:closing_merge_request) { create(:merge_request, :without_diffs, source_project: project) }

          it 'does not update the metrics' do
            subject

            expect(issue.metrics.first_mentioned_in_commit_at).to be_nil
          end
        end

        context 'when `store_first_mentioned_in_commit_on_issue_close` feature flag is off' do
          before do
            stub_feature_flags(store_first_mentioned_in_commit_on_issue_close: { enabled: false, thing: issue.project })
          end

          it 'does not update the metrics' do
            subject

            expect(described_class).not_to receive(:store_first_mentioned_in_commit_at)
            expect(issue.metrics.first_mentioned_in_commit_at).to be_nil
          end
        end
      end
    end

    context "closed by a commit", :sidekiq_might_not_need_inline do
      it 'mentions closure via a commit' do
        perform_enqueued_jobs do
          described_class.new(project, user).close_issue(issue, closed_via: closing_commit)
        end

        email = ActionMailer::Base.deliveries.last

        expect(email.to.first).to eq(user2.email)
        expect(email.subject).to include(issue.title)
        expect(email.body.parts.map(&:body)).to all(include(closing_commit.id))
      end

      context 'when user cannot read the commit' do
        it 'does not mention the commit id' do
          project.project_feature.update_attribute(:repository_access_level, ProjectFeature::DISABLED)
          perform_enqueued_jobs do
            described_class.new(project, user).close_issue(issue, closed_via: closing_commit)
          end

          email = ActionMailer::Base.deliveries.last
          body_text = email.body.parts.map(&:body).join(" ")

          expect(email.to.first).to eq(user2.email)
          expect(email.subject).to include(issue.title)
          expect(body_text).not_to include(closing_commit.id)
        end
      end
    end

    context "valid params" do
      def close_issue
        perform_enqueued_jobs do
          described_class.new(project, user).close_issue(issue)
        end
      end

      it 'closes the issue' do
        close_issue

        expect(issue).to be_valid
        expect(issue).to be_closed
      end

      it 'records closed user' do
        close_issue

        expect(issue.closed_by_id).to be(user.id)
      end

      it 'sends email to user2 about assign of new issue', :sidekiq_might_not_need_inline do
        close_issue

        email = ActionMailer::Base.deliveries.last
        expect(email.to.first).to eq(user2.email)
        expect(email.subject).to include(issue.title)
      end

      it 'creates system note about issue reassign' do
        close_issue

        note = issue.notes.last
        expect(note.note).to include "closed"
      end

      it 'marks todos as done' do
        close_issue

        expect(todo.reload).to be_done
      end

      it 'deletes milestone issue counters cache' do
        issue.update(milestone: create(:milestone, project: project))

        expect_next_instance_of(Milestones::ClosedIssuesCountService, issue.milestone) do |service|
          expect(service).to receive(:delete_cache).and_call_original
        end

        close_issue
      end
    end

    context 'when issue is not confidential' do
      it 'executes issue hooks' do
        expect(project).to receive(:execute_hooks).with(an_instance_of(Hash), :issue_hooks)
        expect(project).to receive(:execute_services).with(an_instance_of(Hash), :issue_hooks)

        described_class.new(project, user).close_issue(issue)
      end
    end

    context 'when issue is confidential' do
      it 'executes confidential issue hooks' do
        issue = create(:issue, :confidential, project: project)

        expect(project).to receive(:execute_hooks).with(an_instance_of(Hash), :confidential_issue_hooks)
        expect(project).to receive(:execute_services).with(an_instance_of(Hash), :confidential_issue_hooks)

        described_class.new(project, user).close_issue(issue)
      end
    end

    context 'internal issues disabled' do
      before do
        project.issues_enabled = false
        project.save!
      end

      it 'does not close the issue' do
        expect(issue).to be_valid
        expect(issue).to be_opened
        expect(todo.reload).to be_pending
      end
    end
  end
end
