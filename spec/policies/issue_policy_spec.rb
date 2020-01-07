# frozen_string_literal: true

require 'spec_helper'

describe IssuePolicy do
  include ExternalAuthorizationServiceHelpers

  let(:guest) { create(:user) }
  let(:author) { create(:user) }
  let(:assignee) { create(:user) }
  let(:reporter) { create(:user) }
  let(:group) { create(:group, :public) }
  let(:reporter_from_group_link) { create(:user) }

  def permissions(user, issue)
    described_class.new(user, issue)
  end

  context 'a private project' do
    let(:non_member) { create(:user) }
    let(:project) { create(:project, :private) }
    let(:issue) { create(:issue, project: project, assignees: [assignee], author: author) }
    let(:issue_no_assignee) { create(:issue, project: project) }

    before do
      project.add_guest(guest)
      project.add_guest(author)
      project.add_guest(assignee)
      project.add_reporter(reporter)

      group.add_reporter(reporter_from_group_link)

      create(:project_group_link, group: group, project: project)
    end

    it 'does not allow non-members to read issues' do
      expect(permissions(non_member, issue)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
      expect(permissions(non_member, issue_no_assignee)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
    end

    it 'allows guests to read issues' do
      expect(permissions(guest, issue)).to be_allowed(:read_issue, :read_issue_iid)
      expect(permissions(guest, issue)).to be_disallowed(:update_issue, :admin_issue)

      expect(permissions(guest, issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid)
      expect(permissions(guest, issue_no_assignee)).to be_disallowed(:update_issue, :admin_issue)
    end

    it 'allows reporters to read, update, and admin issues' do
      expect(permissions(reporter, issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
      expect(permissions(reporter, issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
    end

    it 'allows reporters from group links to read, update, and admin issues' do
      expect(permissions(reporter_from_group_link, issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
      expect(permissions(reporter_from_group_link, issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
    end

    it 'allows issue authors to read and update their issues' do
      expect(permissions(author, issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue)
      expect(permissions(author, issue)).to be_disallowed(:admin_issue)

      expect(permissions(author, issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid)
      expect(permissions(author, issue_no_assignee)).to be_disallowed(:update_issue, :admin_issue)
    end

    it 'allows issue assignees to read and update their issues' do
      expect(permissions(assignee, issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue)
      expect(permissions(assignee, issue)).to be_disallowed(:admin_issue)

      expect(permissions(assignee, issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid)
      expect(permissions(assignee, issue_no_assignee)).to be_disallowed(:update_issue, :admin_issue)
    end

    context 'with confidential issues' do
      let(:confidential_issue) { create(:issue, :confidential, project: project, assignees: [assignee], author: author) }
      let(:confidential_issue_no_assignee) { create(:issue, :confidential, project: project) }

      it 'does not allow non-members to read confidential issues' do
        expect(permissions(non_member, confidential_issue)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
        expect(permissions(non_member, confidential_issue_no_assignee)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
      end

      it 'does not allow guests to read confidential issues' do
        expect(permissions(guest, confidential_issue)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
        expect(permissions(guest, confidential_issue_no_assignee)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
      end

      it 'allows reporters to read, update, and admin confidential issues' do
        expect(permissions(reporter, confidential_issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
        expect(permissions(reporter, confidential_issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
      end

      it 'allows reporters from group links to read, update, and admin confidential issues' do
        expect(permissions(reporter_from_group_link, confidential_issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
        expect(permissions(reporter_from_group_link, confidential_issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
      end

      it 'allows issue authors to read and update their confidential issues' do
        expect(permissions(author, confidential_issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue)
        expect(permissions(author, confidential_issue)).to be_disallowed(:admin_issue)

        expect(permissions(author, confidential_issue_no_assignee)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
      end

      it 'allows issue assignees to read and update their confidential issues' do
        expect(permissions(assignee, confidential_issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue)
        expect(permissions(assignee, confidential_issue)).to be_disallowed(:admin_issue)

        expect(permissions(assignee, confidential_issue_no_assignee)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
      end
    end
  end

  context 'a public project' do
    let(:project) { create(:project, :public) }
    let(:issue) { create(:issue, project: project, assignees: [assignee], author: author) }
    let(:issue_no_assignee) { create(:issue, project: project) }
    let(:issue_locked) { create(:issue, :locked, project: project, author: author, assignees: [assignee]) }

    before do
      project.add_guest(guest)
      project.add_reporter(reporter)

      group.add_reporter(reporter_from_group_link)

      create(:project_group_link, group: group, project: project)
    end

    it 'allows guests to read issues' do
      expect(permissions(guest, issue)).to be_allowed(:read_issue, :read_issue_iid)
      expect(permissions(guest, issue)).to be_disallowed(:update_issue, :admin_issue, :reopen_issue)

      expect(permissions(guest, issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid)
      expect(permissions(guest, issue_no_assignee)).to be_disallowed(:update_issue, :admin_issue, :reopen_issue)

      expect(permissions(guest, issue_locked)).to be_allowed(:read_issue, :read_issue_iid)
      expect(permissions(guest, issue_locked)).to be_disallowed(:update_issue, :admin_issue, :reopen_issue)
    end

    it 'allows reporters to read, update, reopen, and admin issues' do
      expect(permissions(reporter, issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :reopen_issue)
      expect(permissions(reporter, issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :reopen_issue)
      expect(permissions(reporter, issue_locked)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
      expect(permissions(reporter, issue_locked)).to be_disallowed(:reopen_issue)
    end

    it 'allows reporters from group links to read, update, reopen and admin issues' do
      expect(permissions(reporter_from_group_link, issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :reopen_issue)
      expect(permissions(reporter_from_group_link, issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :reopen_issue)
      expect(permissions(reporter_from_group_link, issue_locked)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
      expect(permissions(reporter_from_group_link, issue_locked)).to be_disallowed(:reopen_issue)
    end

    it 'allows issue authors to read, reopen and update their issues' do
      expect(permissions(author, issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :reopen_issue)
      expect(permissions(author, issue)).to be_disallowed(:admin_issue)

      expect(permissions(author, issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid)
      expect(permissions(author, issue_no_assignee)).to be_disallowed(:update_issue, :admin_issue, :reopen_issue)

      expect(permissions(author, issue_locked)).to be_allowed(:read_issue, :read_issue_iid, :update_issue)
      expect(permissions(author, issue_locked)).to be_disallowed(:admin_issue, :reopen_issue)
    end

    it 'allows issue assignees to read, reopen and update their issues' do
      expect(permissions(assignee, issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :reopen_issue)
      expect(permissions(assignee, issue)).to be_disallowed(:admin_issue)

      expect(permissions(assignee, issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid)
      expect(permissions(assignee, issue_no_assignee)).to be_disallowed(:update_issue, :admin_issue, :reopen_issue)

      expect(permissions(assignee, issue_locked)).to be_allowed(:read_issue, :read_issue_iid, :update_issue)
      expect(permissions(assignee, issue_locked)).to be_disallowed(:admin_issue, :reopen_issue)
    end

    context 'when issues are private' do
      before do
        project.project_feature.update(issues_access_level: ProjectFeature::PRIVATE)
      end
      let(:issue) { create(:issue, project: project, author: author) }
      let(:visitor) { create(:user) }
      let(:admin) { create(:user, :admin) }

      it 'forbids visitors from viewing issues' do
        expect(permissions(visitor, issue)).to be_disallowed(:read_issue)
      end
      it 'forbids visitors from commenting' do
        expect(permissions(visitor, issue)).to be_disallowed(:create_note)
      end
      it 'allows guests to view' do
        expect(permissions(guest, issue)).to be_allowed(:read_issue)
      end
      it 'allows guests to comment' do
        expect(permissions(guest, issue)).to be_allowed(:create_note)
      end
      it 'allows admins to view' do
        expect(permissions(admin, issue)).to be_allowed(:read_issue)
      end
      it 'allows admins to comment' do
        expect(permissions(admin, issue)).to be_allowed(:create_note)
      end
    end

    context 'with confidential issues' do
      let(:confidential_issue) { create(:issue, :confidential, project: project, assignees: [assignee], author: author) }
      let(:confidential_issue_no_assignee) { create(:issue, :confidential, project: project) }

      it 'does not allow guests to read confidential issues' do
        expect(permissions(guest, confidential_issue)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
        expect(permissions(guest, confidential_issue_no_assignee)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
      end

      it 'allows reporters to read, update, and admin confidential issues' do
        expect(permissions(reporter, confidential_issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
        expect(permissions(reporter, confidential_issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
      end

      it 'allows reporter from group links to read, update, and admin confidential issues' do
        expect(permissions(reporter_from_group_link, confidential_issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
        expect(permissions(reporter_from_group_link, confidential_issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
      end

      it 'allows issue authors to read and update their confidential issues' do
        expect(permissions(author, confidential_issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue)
        expect(permissions(author, confidential_issue)).to be_disallowed(:admin_issue)

        expect(permissions(author, confidential_issue_no_assignee)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
      end

      it 'allows issue assignees to read and update their confidential issues' do
        expect(permissions(assignee, confidential_issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue)
        expect(permissions(assignee, confidential_issue)).to be_disallowed(:admin_issue)

        expect(permissions(assignee, confidential_issue_no_assignee)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
      end
    end
  end

  context 'with external authorization enabled' do
    let(:user) { create(:user) }
    let(:project) { create(:project, :public) }
    let(:issue) { create(:issue, project: project) }
    let(:policies) { described_class.new(user, issue) }

    before do
      enable_external_authorization_service_check
    end

    it 'can read the issue iid without accessing the external service' do
      expect(::Gitlab::ExternalAuthorization).not_to receive(:access_allowed?)

      expect(policies).to be_allowed(:read_issue_iid)
    end
  end
end
