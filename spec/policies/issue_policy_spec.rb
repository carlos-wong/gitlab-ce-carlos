# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IssuePolicy do
  include ExternalAuthorizationServiceHelpers

  let(:guest) { create(:user) }
  let(:author) { create(:user) }
  let(:assignee) { create(:user) }
  let(:reporter) { create(:user) }
  let(:group) { create(:group, :public) }
  let(:reporter_from_group_link) { create(:user) }
  let(:non_member) { create(:user) }
  let(:support_bot) { User.support_bot }
  let(:alert_bot) { User.alert_bot }

  def permissions(user, issue)
    described_class.new(user, issue)
  end

  shared_examples 'support bot with service desk enabled' do
    before do
      allow(::Gitlab::IncomingEmail).to receive(:enabled?) { true }
      allow(::Gitlab::IncomingEmail).to receive(:supports_wildcard?) { true }

      project.update!(service_desk_enabled: true)
    end

    it 'allows support_bot to read issues, create and set metadata on new issues' do
      expect(permissions(support_bot, issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
      expect(permissions(support_bot, issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
      expect(permissions(support_bot, new_issue)).to be_allowed(:create_issue, :set_issue_metadata, :set_confidentiality)
    end
  end

  shared_examples 'support bot with service desk disabled' do
    it 'does not allow support_bot to read issues, create and set metadata on new issues' do
      expect(permissions(support_bot, issue)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
      expect(permissions(support_bot, issue_no_assignee)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
      expect(permissions(support_bot, new_issue)).to be_disallowed(:create_issue, :set_issue_metadata, :set_confidentiality)
    end
  end

  shared_examples 'alert bot' do
    it 'allows alert_bot to read and set metadata on issues' do
      expect(permissions(alert_bot, issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
      expect(permissions(alert_bot, issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
      expect(permissions(alert_bot, new_issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
    end
  end

  context 'a private project' do
    let(:project) { create(:project, :private) }
    let(:issue) { create(:issue, project: project, assignees: [assignee], author: author) }
    let(:issue_no_assignee) { create(:issue, project: project) }
    let(:new_issue) { build(:issue, project: project, assignees: [assignee], author: author) }

    before do
      project.add_guest(guest)
      project.add_guest(author)
      project.add_guest(assignee)
      project.add_reporter(reporter)

      group.add_reporter(reporter_from_group_link)

      create(:project_group_link, group: group, project: project)
    end

    it 'allows guests to read issues' do
      expect(permissions(guest, issue)).to be_allowed(:read_issue, :read_issue_iid)
      expect(permissions(guest, issue)).to be_disallowed(:update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)

      expect(permissions(guest, issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid)
      expect(permissions(guest, issue_no_assignee)).to be_disallowed(:update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)

      expect(permissions(guest, new_issue)).to be_allowed(:create_issue, :set_issue_metadata, :set_confidentiality)
    end

    it 'allows reporters to read, update, and admin issues' do
      expect(permissions(reporter, issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
      expect(permissions(reporter, issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
      expect(permissions(reporter, new_issue)).to be_allowed(:create_issue, :set_issue_metadata, :set_confidentiality)
    end

    it 'allows reporters from group links to read, update, and admin issues' do
      expect(permissions(reporter_from_group_link, issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
      expect(permissions(reporter_from_group_link, issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
      expect(permissions(reporter_from_group_link, new_issue)).to be_allowed(:create_issue, :set_issue_metadata, :set_confidentiality)
    end

    it 'allows issue authors to read and update their issues' do
      expect(permissions(author, issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue)
      expect(permissions(author, issue)).to be_disallowed(:admin_issue, :set_issue_metadata, :set_confidentiality)

      expect(permissions(author, issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid)
      expect(permissions(author, issue_no_assignee)).to be_disallowed(:update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)

      expect(permissions(author, new_issue)).to be_allowed(:create_issue, :set_issue_metadata, :set_confidentiality)
    end

    it 'allows issue assignees to read and update their issues' do
      expect(permissions(assignee, issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue)
      expect(permissions(assignee, issue)).to be_disallowed(:admin_issue, :set_issue_metadata, :set_confidentiality)

      expect(permissions(assignee, issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid)
      expect(permissions(assignee, issue_no_assignee)).to be_disallowed(:update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)

      expect(permissions(assignee, new_issue)).to be_allowed(:create_issue, :set_issue_metadata, :set_confidentiality)
    end

    it 'does not allow non-members to read, update or create issues' do
      expect(permissions(non_member, issue)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
      expect(permissions(non_member, issue_no_assignee)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
      expect(permissions(non_member, new_issue)).to be_disallowed(:create_issue, :set_issue_metadata, :set_confidentiality)
    end

    it_behaves_like 'alert bot'
    it_behaves_like 'support bot with service desk disabled'
    it_behaves_like 'support bot with service desk enabled'

    context 'with confidential issues' do
      let(:confidential_issue) { create(:issue, :confidential, project: project, assignees: [assignee], author: author) }
      let(:confidential_issue_no_assignee) { create(:issue, :confidential, project: project) }

      it 'does not allow non-members to read confidential issues' do
        expect(permissions(non_member, confidential_issue)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
        expect(permissions(non_member, confidential_issue_no_assignee)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
      end

      it 'does not allow guests to read confidential issues' do
        expect(permissions(guest, confidential_issue)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
        expect(permissions(guest, confidential_issue_no_assignee)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
      end

      it 'allows reporters to read, update, and admin confidential issues' do
        expect(permissions(reporter, confidential_issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
        expect(permissions(reporter, confidential_issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
      end

      it 'allows reporters from group links to read, update, and admin confidential issues' do
        expect(permissions(reporter_from_group_link, confidential_issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
        expect(permissions(reporter_from_group_link, confidential_issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
      end

      it 'allows issue authors to read and update their confidential issues' do
        expect(permissions(author, confidential_issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue)
        expect(permissions(author, confidential_issue)).to be_disallowed(:admin_issue, :set_issue_metadata, :set_confidentiality)

        expect(permissions(author, confidential_issue_no_assignee)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
        expect(permissions(author, confidential_issue_no_assignee)).to be_disallowed(:admin_issue, :set_issue_metadata, :set_confidentiality)
      end

      it 'does not allow issue author to read or update confidential issue moved to an private project' do
        confidential_issue.project = create(:project, :private)

        expect(permissions(author, confidential_issue)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :set_issue_metadata, :set_confidentiality)
      end

      it 'allows issue assignees to read and update their confidential issues' do
        expect(permissions(assignee, confidential_issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue)
        expect(permissions(assignee, confidential_issue)).to be_disallowed(:admin_issue, :set_issue_metadata, :set_confidentiality)

        expect(permissions(assignee, confidential_issue_no_assignee)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
      end

      it 'does not allow issue assignees to read or update confidential issue moved to an private project' do
        confidential_issue.project = create(:project, :private)

        expect(permissions(assignee, confidential_issue)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :set_issue_metadata, :set_confidentiality)
      end
    end
  end

  context 'a public project' do
    let(:project) { create(:project, :public) }
    let(:issue) { create(:issue, project: project, assignees: [assignee], author: author) }
    let(:issue_no_assignee) { create(:issue, project: project) }
    let(:issue_locked) { create(:issue, :locked, project: project, author: author, assignees: [assignee]) }
    let(:new_issue) { build(:issue, project: project) }

    before do
      project.add_guest(guest)
      project.add_reporter(reporter)

      group.add_reporter(reporter_from_group_link)

      create(:project_group_link, group: group, project: project)
    end

    it 'does not allow anonymous user to create todos' do
      expect(permissions(nil, issue)).to be_allowed(:read_issue)
      expect(permissions(nil, issue)).to be_disallowed(:create_todo, :update_subscription, :set_issue_metadata, :set_confidentiality)
      expect(permissions(nil, new_issue)).to be_disallowed(:create_issue, :set_issue_metadata, :set_confidentiality)
    end

    it 'allows guests to read issues' do
      expect(permissions(guest, issue)).to be_allowed(:read_issue, :read_issue_iid, :create_todo, :update_subscription)
      expect(permissions(guest, issue)).to be_disallowed(:update_issue, :admin_issue, :reopen_issue, :set_issue_metadata, :set_confidentiality)

      expect(permissions(guest, issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid)
      expect(permissions(guest, issue_no_assignee)).to be_disallowed(:update_issue, :admin_issue, :reopen_issue, :set_issue_metadata, :set_confidentiality)

      expect(permissions(guest, issue_locked)).to be_allowed(:read_issue, :read_issue_iid)
      expect(permissions(guest, issue_locked)).to be_disallowed(:update_issue, :admin_issue, :reopen_issue, :set_issue_metadata, :set_confidentiality)

      expect(permissions(guest, new_issue)).to be_allowed(:create_issue, :set_issue_metadata, :set_confidentiality)
    end

    it 'allows reporters to read, update, reopen, and admin issues' do
      expect(permissions(reporter, issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :reopen_issue, :set_issue_metadata, :set_confidentiality)
      expect(permissions(reporter, issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :reopen_issue, :set_issue_metadata, :set_confidentiality)
      expect(permissions(reporter, issue_locked)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
      expect(permissions(reporter, issue_locked)).to be_disallowed(:reopen_issue)
      expect(permissions(reporter, new_issue)).to be_allowed(:create_issue, :set_issue_metadata, :set_confidentiality)
    end

    it 'allows reporters from group links to read, update, reopen and admin issues' do
      expect(permissions(reporter_from_group_link, issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :reopen_issue, :set_issue_metadata, :set_confidentiality)
      expect(permissions(reporter_from_group_link, issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :reopen_issue, :set_issue_metadata, :set_confidentiality)
      expect(permissions(reporter_from_group_link, issue_locked)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
      expect(permissions(reporter_from_group_link, issue_locked)).to be_disallowed(:reopen_issue)
      expect(permissions(reporter, new_issue)).to be_allowed(:create_issue, :set_issue_metadata, :set_confidentiality)
    end

    it 'allows issue authors to read, reopen and update their issues' do
      expect(permissions(author, issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :reopen_issue)
      expect(permissions(author, issue)).to be_disallowed(:admin_issue, :set_issue_metadata, :set_confidentiality)

      expect(permissions(author, issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid)
      expect(permissions(author, issue_no_assignee)).to be_disallowed(:update_issue, :admin_issue, :reopen_issue, :set_issue_metadata, :set_confidentiality)

      expect(permissions(author, issue_locked)).to be_allowed(:read_issue, :read_issue_iid, :update_issue)
      expect(permissions(author, issue_locked)).to be_disallowed(:admin_issue, :reopen_issue, :set_issue_metadata, :set_confidentiality)

      expect(permissions(author, new_issue)).to be_allowed(:create_issue)
      expect(permissions(author, new_issue)).to be_disallowed(:set_issue_metadata)
    end

    it 'allows issue assignees to read, reopen and update their issues' do
      expect(permissions(assignee, issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :reopen_issue)
      expect(permissions(assignee, issue)).to be_disallowed(:admin_issue, :set_issue_metadata, :set_confidentiality)

      expect(permissions(assignee, issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid)
      expect(permissions(assignee, issue_no_assignee)).to be_disallowed(:update_issue, :admin_issue, :reopen_issue, :set_issue_metadata, :set_confidentiality)

      expect(permissions(assignee, issue_locked)).to be_allowed(:read_issue, :read_issue_iid, :update_issue)
      expect(permissions(assignee, issue_locked)).to be_disallowed(:admin_issue, :reopen_issue, :set_issue_metadata, :set_confidentiality)
    end

    it 'allows non-members to read and create issues' do
      expect(permissions(non_member, issue)).to be_allowed(:read_issue, :read_issue_iid)
      expect(permissions(non_member, issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid)
      expect(permissions(non_member, new_issue)).to be_allowed(:create_issue)
    end

    it 'allows non-members to read issues' do
      expect(permissions(non_member, issue)).to be_allowed(:read_issue, :read_issue_iid)
      expect(permissions(non_member, issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid)
    end

    it 'does not allow non-members to update, admin or set metadata except for set confidential flag' do
      expect(permissions(non_member, issue)).to be_disallowed(:update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
      expect(permissions(non_member, issue_no_assignee)).to be_disallowed(:update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
      expect(permissions(non_member, new_issue)).to be_disallowed(:set_issue_metadata)
      # this is allowed for non-members in a public project, as we want to let users report security issues
      # see https://gitlab.com/gitlab-org/gitlab/-/issues/337665
      expect(permissions(non_member, new_issue)).to be_allowed(:set_confidentiality)
    end

    it 'allows support_bot to read issues' do
      # support_bot is still allowed read access in public projects through :public_access permission,
      # see project_policy public_access rules policy (rule { can?(:public_access) }.policy {...})
      expect(permissions(support_bot, issue)).to be_allowed(:read_issue, :read_issue_iid)
      expect(permissions(support_bot, issue)).to be_disallowed(:update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)

      expect(permissions(support_bot, issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid)
      expect(permissions(support_bot, issue_no_assignee)).to be_disallowed(:update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)

      expect(permissions(support_bot, new_issue)).to be_disallowed(:create_issue, :set_issue_metadata, :set_confidentiality)
    end

    it_behaves_like 'alert bot'
    it_behaves_like 'support bot with service desk enabled'

    context 'when issues are private' do
      before do
        project.project_feature.update!(issues_access_level: ProjectFeature::PRIVATE)
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
      it 'forbids visitors from subscribing' do
        expect(permissions(visitor, issue)).to be_disallowed(:update_subscription)
      end
      it 'allows guests to view' do
        expect(permissions(guest, issue)).to be_allowed(:read_issue)
      end
      it 'allows guests to comment' do
        expect(permissions(guest, issue)).to be_allowed(:create_note)
      end
      it 'allows guests to subscribe' do
        expect(permissions(guest, issue)).to be_allowed(:update_subscription)
      end

      context 'when admin mode is enabled', :enable_admin_mode do
        it 'allows admins to view' do
          expect(permissions(admin, issue)).to be_allowed(:read_issue)
        end

        it 'allows admins to comment' do
          expect(permissions(admin, issue)).to be_allowed(:create_note)
        end
      end

      context 'when admin mode is disabled' do
        it 'forbids admins to view' do
          expect(permissions(admin, issue)).to be_disallowed(:read_issue)
        end

        it 'forbids admins to comment' do
          expect(permissions(admin, issue)).to be_disallowed(:create_note)
        end
      end

      it 'does not allow non-members to update or create issues' do
        expect(permissions(non_member, issue)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
        expect(permissions(non_member, issue_no_assignee)).to be_disallowed(:update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
        expect(permissions(non_member, new_issue)).to be_disallowed(:create_issue, :set_issue_metadata, :set_confidentiality)
      end

      it_behaves_like 'alert bot'
      it_behaves_like 'support bot with service desk disabled'
      it_behaves_like 'support bot with service desk enabled'
    end

    context 'with confidential issues' do
      let(:confidential_issue) { create(:issue, :confidential, project: project, assignees: [assignee], author: author) }
      let(:confidential_issue_no_assignee) { create(:issue, :confidential, project: project) }

      it 'does not allow guests to read confidential issues' do
        expect(permissions(guest, confidential_issue)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
        expect(permissions(guest, confidential_issue_no_assignee)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
      end

      it 'allows reporters to read, update, and admin confidential issues' do
        expect(permissions(reporter, confidential_issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
        expect(permissions(reporter, confidential_issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
      end

      it 'allows reporter from group links to read, update, and admin confidential issues' do
        expect(permissions(reporter_from_group_link, confidential_issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue)
        expect(permissions(reporter_from_group_link, confidential_issue_no_assignee)).to be_allowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
      end

      it 'allows issue authors to read and update their confidential issues' do
        expect(permissions(author, confidential_issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue)
        expect(permissions(author, confidential_issue)).to be_disallowed(:admin_issue, :set_issue_metadata, :set_confidentiality)

        expect(permissions(author, confidential_issue_no_assignee)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
      end

      it 'allows issue assignees to read and update their confidential issues' do
        expect(permissions(assignee, confidential_issue)).to be_allowed(:read_issue, :read_issue_iid, :update_issue)
        expect(permissions(assignee, confidential_issue)).to be_disallowed(:admin_issue, :set_issue_metadata, :set_confidentiality)

        expect(permissions(assignee, confidential_issue_no_assignee)).to be_disallowed(:read_issue, :read_issue_iid, :update_issue, :admin_issue, :set_issue_metadata, :set_confidentiality)
      end
    end

    context 'with a hidden issue' do
      let(:user) { create(:user) }
      let(:banned_user) { create(:user, :banned) }
      let(:admin) { create(:user, :admin)}
      let(:hidden_issue) { create(:issue, project: project, author: banned_user) }

      it 'does not allow non-admin user to read the issue' do
        expect(permissions(user, hidden_issue)).not_to be_allowed(:read_issue)
      end

      it 'allows admin to read the issue', :enable_admin_mode do
        expect(permissions(admin, hidden_issue)).to be_allowed(:read_issue)
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

  describe 'crm permissions' do
    let(:user) { create(:user) }
    let(:subgroup) { create(:group, :crm_enabled, parent: create(:group, :crm_enabled)) }
    let(:project) { create(:project, group: subgroup) }
    let(:issue) { create(:issue, project: project) }
    let(:policies) { described_class.new(user, issue) }

    context 'when project reporter' do
      it 'is disallowed' do
        project.add_reporter(user)

        expect(policies).to be_disallowed(:read_crm_contacts)
        expect(policies).to be_disallowed(:set_issue_crm_contacts)
      end
    end

    context 'when subgroup reporter' do
      it 'is allowed' do
        subgroup.add_reporter(user)

        expect(policies).to be_disallowed(:read_crm_contacts)
        expect(policies).to be_disallowed(:set_issue_crm_contacts)
      end
    end

    context 'when root group reporter' do
      it 'is allowed' do
        subgroup.parent.add_reporter(user)

        expect(policies).to be_allowed(:read_crm_contacts)
        expect(policies).to be_allowed(:set_issue_crm_contacts)
      end
    end

    context 'when crm disabled on subgroup' do
      let(:subgroup) { create(:group, parent: create(:group, :crm_enabled)) }

      it 'is disallowed' do
        subgroup.parent.add_reporter(user)

        expect(policies).to be_disallowed(:read_crm_contacts)
        expect(policies).to be_disallowed(:set_issue_crm_contacts)
      end
    end

    context 'when peronsal namespace' do
      let(:project) { create(:project) }

      it 'is disallowed' do
        project.add_reporter(user)

        expect(policies).to be_disallowed(:read_crm_contacts)
        expect(policies).to be_disallowed(:set_issue_crm_contacts)
      end
    end
  end
end
