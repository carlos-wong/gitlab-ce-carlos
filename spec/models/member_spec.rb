# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Member do
  include ExclusiveLeaseHelpers

  using RSpec::Parameterized::TableSyntax

  describe 'Associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:member_namespace) }
    it { is_expected.to have_one(:member_task) }
  end

  describe 'Validation' do
    subject { described_class.new(access_level: Member::GUEST) }

    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_presence_of(:source) }

    context 'expires_at' do
      it { is_expected.not_to allow_value(Date.yesterday).for(:expires_at) }
      it { is_expected.to allow_value(Date.tomorrow).for(:expires_at) }
      it { is_expected.to allow_value(Date.today).for(:expires_at) }
      it { is_expected.to allow_value(nil).for(:expires_at) }
    end

    it_behaves_like 'an object with email-formatted attributes', :invite_email do
      subject { build(:project_member) }
    end

    context 'when an invite email is provided' do
      let_it_be(:project) { create(:project) }

      let(:member) { build(:project_member, source: project, invite_email: "user@example.com", user: nil) }

      it "doesn't require a user" do
        expect(member).to be_valid
      end

      it 'requires a valid invite email' do
        member.invite_email = "nope"

        expect(member).not_to be_valid
      end

      it 'requires a unique invite email scoped to this source' do
        create(:project_member, source: member.source, invite_email: member.invite_email)

        expect(member).not_to be_valid
      end
    end

    context 'when an invite email is not provided' do
      let(:member) { build(:project_member) }

      it 'requires a user' do
        member.user = nil

        expect(member).not_to be_valid
      end

      it 'is valid otherwise' do
        expect(member).to be_valid
      end
    end

    context 'with admin signup restrictions' do
      let(:expected_message) { _('is not allowed for this group. Check with your administrator.') }

      context 'when allowed domains for signup is enabled' do
        before do
          stub_application_setting(domain_allowlist: ['example.com'])
        end

        it 'adds an error message when email is not accepted' do
          member = build(:group_member, :invited, invite_email: 'info@gitlab.com')

          expect(member).not_to be_valid
          expect(member.errors.messages[:user].first).to eq(expected_message)
        end
      end

      context 'when denylist is enabled' do
        before do
          stub_application_setting(domain_denylist_enabled: true)
          stub_application_setting(domain_denylist: ['example.org'])
        end

        it 'adds an error message when email is denied' do
          member = build(:group_member, :invited, invite_email: 'denylist@example.org')

          expect(member).not_to be_valid
          expect(member.errors.messages[:user].first).to eq(expected_message)
        end
      end

      context 'when email restrictions is enabled' do
        before do
          stub_application_setting(email_restrictions_enabled: true)
          stub_application_setting(email_restrictions: '([\+]|\b(\w*gitlab.com\w*)\b)')
        end

        it 'adds an error message when email is not accepted' do
          member = build(:group_member, :invited, invite_email: 'info@gitlab.com')

          expect(member).not_to be_valid
          expect(member.errors.messages[:user].first).to eq(expected_message)
        end
      end
    end

    context 'when a child member inherits its access level' do
      let(:user) { create(:user) }
      let(:member) { create(:group_member, :developer, user: user) }
      let(:child_group) { create(:group, parent: member.group) }
      let(:child_member) { build(:group_member, group: child_group, user: user) }

      it 'requires a higher level' do
        child_member.access_level = GroupMember::REPORTER

        child_member.validate

        expect(child_member).not_to be_valid
      end

      # Membership in a subgroup confers certain access rights, such as being
      # able to merge or push code to protected branches.
      it 'is valid with an equal level' do
        child_member.access_level = GroupMember::DEVELOPER

        child_member.validate

        expect(child_member).to be_valid
      end

      it 'is valid with a higher level' do
        child_member.access_level = GroupMember::MAINTAINER

        child_member.validate

        expect(child_member).to be_valid
      end
    end

    context 'project bots' do
      let_it_be(:project_bot) { create(:user, :project_bot) }

      let(:new_member) { build(:project_member, user_id: project_bot.id) }

      context 'not a member of any group or project' do
        it 'is valid' do
          expect(new_member).to be_valid
        end
      end

      context 'already member of a project' do
        before do
          unrelated_project = create(:project)
          unrelated_project.add_maintainer(project_bot)
        end

        it 'is not valid' do
          expect(new_member).not_to be_valid
        end
      end
    end
  end

  describe 'Scopes & finders' do
    let_it_be(:project) { create(:project, :public) }
    let_it_be(:group) { create(:group) }
    let_it_be(:blocked_pending_approval_user) { create(:user, :blocked_pending_approval ) }
    let_it_be(:blocked_pending_approval_project_member) { create(:project_member, :invited, :developer, project: project, invite_email: blocked_pending_approval_user.email) }
    let_it_be(:awaiting_group_member) { create(:group_member, :awaiting, group: group) }
    let_it_be(:awaiting_project_member) { create(:project_member, :awaiting, project: project) }

    before_all do
      @owner_user = create(:user).tap { |u| group.add_owner(u) }
      @owner = group.members.find_by(user_id: @owner_user.id)

      @maintainer_user = create(:user).tap { |u| project.add_maintainer(u) }
      @maintainer = project.members.find_by(user_id: @maintainer_user.id)

      @blocked_maintainer_user = create(:user).tap do |u|
        project.add_maintainer(u)

        u.block!
      end
      @blocked_developer_user = create(:user).tap do |u|
        project.add_developer(u)

        u.block!
      end
      @blocked_maintainer = project.members.find_by(user_id: @blocked_maintainer_user.id, access_level: Gitlab::Access::MAINTAINER)
      @blocked_developer = project.members.find_by(user_id: @blocked_developer_user.id, access_level: Gitlab::Access::DEVELOPER)

      @invited_member = create(:project_member, :invited, :developer, project: project)

      accepted_invite_user = build(:user, state: :active)
      @accepted_invite_member = create(:project_member, :invited, :developer, project: project)
                                      .tap { |u| u.accept_invite!(accepted_invite_user) }

      requested_user = create(:user).tap { |u| project.request_access(u) }
      @requested_member = project.requesters.find_by(user_id: requested_user.id)

      accepted_request_user = create(:user).tap { |u| project.request_access(u) }
      @accepted_request_member = project.requesters.find_by(user_id: accepted_request_user.id).tap { |m| m.accept_request }
      @member_with_minimal_access = create(:group_member, :minimal_access, source: group)
    end

    describe '.access_for_user_ids' do
      it 'returns the right access levels' do
        users = [@owner_user.id, @maintainer_user.id, @blocked_maintainer_user.id]
        expected = {
          @owner_user.id => Gitlab::Access::OWNER,
          @maintainer_user.id => Gitlab::Access::MAINTAINER
        }

        expect(described_class.access_for_user_ids(users)).to eq(expected)
      end
    end

    describe '.in_hierarchy' do
      let(:root_ancestor) { create(:group) }
      let(:project) { create(:project, group: root_ancestor) }
      let(:subgroup) { create(:group, parent: root_ancestor) }
      let(:subgroup_project) { create(:project, group: subgroup) }

      let!(:root_ancestor_member) { create(:group_member, group: root_ancestor) }
      let!(:project_member) { create(:project_member, project: project) }
      let!(:subgroup_member) { create(:group_member, group: subgroup) }
      let!(:subgroup_project_member) { create(:project_member, project: subgroup_project) }

      let(:hierarchy_members) do
        [
          root_ancestor_member,
          project_member,
          subgroup_member,
          subgroup_project_member
        ]
      end

      subject { Member.in_hierarchy(project) }

      it { is_expected.to contain_exactly(*hierarchy_members) }

      context 'with scope prefix' do
        subject { Member.where.not(source: project).in_hierarchy(subgroup) }

        it { is_expected.to contain_exactly(root_ancestor_member, subgroup_member, subgroup_project_member) }
      end

      context 'with scope suffix' do
        subject { Member.in_hierarchy(project).where.not(source: project) }

        it { is_expected.to contain_exactly(root_ancestor_member, subgroup_member, subgroup_project_member) }
      end
    end

    describe '.invite' do
      it { expect(described_class.invite).not_to include @maintainer }
      it { expect(described_class.invite).to include @invited_member }
      it { expect(described_class.invite).not_to include @accepted_invite_member }
      it { expect(described_class.invite).not_to include @requested_member }
      it { expect(described_class.invite).not_to include @accepted_request_member }
    end

    describe '.non_invite' do
      it { expect(described_class.non_invite).to include @maintainer }
      it { expect(described_class.non_invite).not_to include @invited_member }
      it { expect(described_class.non_invite).to include @accepted_invite_member }
      it { expect(described_class.non_invite).to include @requested_member }
      it { expect(described_class.non_invite).to include @accepted_request_member }
    end

    describe '.non_minimal_access' do
      it { expect(described_class.non_minimal_access).to include @maintainer }
      it { expect(described_class.non_minimal_access).to include @invited_member }
      it { expect(described_class.non_minimal_access).to include @accepted_invite_member }
      it { expect(described_class.non_minimal_access).to include @requested_member }
      it { expect(described_class.non_minimal_access).to include @accepted_request_member }
      it { expect(described_class.non_minimal_access).not_to include @member_with_minimal_access }
    end

    describe '.request' do
      it { expect(described_class.request).not_to include @maintainer }
      it { expect(described_class.request).not_to include @invited_member }
      it { expect(described_class.request).not_to include @accepted_invite_member }
      it { expect(described_class.request).to include @requested_member }
      it { expect(described_class.request).not_to include @accepted_request_member }
    end

    describe '.non_request' do
      it { expect(described_class.non_request).to include @maintainer }
      it { expect(described_class.non_request).to include @invited_member }
      it { expect(described_class.non_request).to include @accepted_invite_member }
      it { expect(described_class.non_request).not_to include @requested_member }
      it { expect(described_class.non_request).to include @accepted_request_member }
    end

    describe '.not_accepted_invitations' do
      let_it_be(:not_accepted_invitation) { create(:project_member, :invited) }
      let_it_be(:accepted_invitation) { create(:project_member, :invited, invite_accepted_at: Date.today) }

      subject { described_class.not_accepted_invitations }

      it { is_expected.to include(not_accepted_invitation) }
      it { is_expected.not_to include(accepted_invitation) }
    end

    describe '.not_accepted_invitations_by_user' do
      let(:invited_by_user) { create(:project_member, :invited, project: project, created_by: @owner_user) }

      before do
        create(:project_member, :invited, invite_email: 'test@test.com', project: project, created_by: @owner_user, invite_accepted_at: Time.zone.now)
        create(:project_member, :invited, invite_email: 'test2@test.com', project: project, created_by: @maintainer_user)
      end

      subject { described_class.not_accepted_invitations_by_user(@owner_user) }

      it { is_expected.to contain_exactly(invited_by_user) }
    end

    describe '.not_expired' do
      let_it_be(:expiring_yesterday) { create(:group_member, expires_at: 1.day.from_now) }
      let_it_be(:expiring_today) { create(:group_member, expires_at: 2.days.from_now) }
      let_it_be(:expiring_tomorrow) { create(:group_member, expires_at: 3.days.from_now) }
      let_it_be(:not_expiring) { create(:group_member) }

      subject { described_class.not_expired }

      around do |example|
        travel_to(2.days.from_now) { example.run }
      end

      it { is_expected.not_to include(expiring_yesterday, expiring_today) }
      it { is_expected.to include(expiring_tomorrow, not_expiring) }
    end

    describe '.created_today' do
      let_it_be(:now) { Time.current }
      let_it_be(:created_today) { create(:group_member, created_at: now.beginning_of_day) }
      let_it_be(:created_yesterday) { create(:group_member, created_at: now - 1.day) }

      before do
        travel_to now
      end

      subject { described_class.created_today }

      it { is_expected.not_to include(created_yesterday) }
      it { is_expected.to include(created_today) }
    end

    describe '.last_ten_days_excluding_today' do
      let_it_be(:now) { Time.current }
      let_it_be(:created_today) { create(:group_member, created_at: now.beginning_of_day) }
      let_it_be(:created_yesterday) { create(:group_member, created_at: now - 1.day) }
      let_it_be(:created_eleven_days_ago) { create(:group_member, created_at: now - 11.days) }

      subject { described_class.last_ten_days_excluding_today }

      before do
        travel_to now
      end

      it { is_expected.to include(created_yesterday) }
      it { is_expected.not_to include(created_today, created_eleven_days_ago) }
    end

    describe '.search_invite_email' do
      it 'returns only members the matching e-mail' do
        invited_member = create(:group_member, :invited, invite_email: 'invited@example.com')

        invited = described_class.search_invite_email(invited_member.invite_email)

        expect(invited.count).to eq(1)
        expect(invited.first).to eq(invited_member)

        expect(described_class.search_invite_email('bad-email@example.com').count).to eq(0)
      end
    end

    describe '.developers' do
      subject { described_class.developers.to_a }

      it { is_expected.not_to include @owner }
      it { is_expected.not_to include @maintainer }
      it { is_expected.to include @invited_member }
      it { is_expected.to include @accepted_invite_member }
      it { is_expected.not_to include @requested_member }
      it { is_expected.to include @accepted_request_member }
      it { is_expected.not_to include @blocked_maintainer }
      it { is_expected.not_to include @blocked_developer }
    end

    describe '.owners_and_maintainers' do
      it { expect(described_class.owners_and_maintainers).to include @owner }
      it { expect(described_class.owners_and_maintainers).to include @maintainer }
      it { expect(described_class.owners_and_maintainers).not_to include @invited_member }
      it { expect(described_class.owners_and_maintainers).not_to include @accepted_invite_member }
      it { expect(described_class.owners_and_maintainers).not_to include @requested_member }
      it { expect(described_class.owners_and_maintainers).not_to include @accepted_request_member }
      it { expect(described_class.owners_and_maintainers).not_to include @blocked_maintainer }
    end

    describe '.has_access' do
      subject { described_class.has_access.to_a }

      it { is_expected.to include @owner }
      it { is_expected.to include @maintainer }
      it { is_expected.to include @invited_member }
      it { is_expected.to include @accepted_invite_member }
      it { is_expected.not_to include @requested_member }
      it { is_expected.to include @accepted_request_member }
      it { is_expected.not_to include @blocked_maintainer }
      it { is_expected.not_to include @blocked_developer }
    end

    describe '.active' do
      subject { described_class.active.to_a }

      it { is_expected.to include @owner }
      it { is_expected.to include @maintainer }
      it { is_expected.to include @invited_member }
      it { is_expected.to include @accepted_invite_member }
      it { is_expected.not_to include @requested_member }
      it { is_expected.to include @accepted_request_member }
      it { is_expected.not_to include @blocked_maintainer }
      it { is_expected.not_to include @blocked_developer }
      it { is_expected.not_to include @member_with_minimal_access }
    end

    describe '.blocked' do
      subject { described_class.blocked.to_a }

      it { is_expected.not_to include @owner }
      it { is_expected.not_to include @maintainer }
      it { is_expected.not_to include @invited_member }
      it { is_expected.not_to include @accepted_invite_member }
      it { is_expected.not_to include @requested_member }
      it { is_expected.not_to include @accepted_request_member }
      it { is_expected.to include @blocked_maintainer }
      it { is_expected.to include @blocked_developer }
      it { is_expected.not_to include @member_with_minimal_access }
    end

    describe '.active_without_invites_and_requests' do
      subject { described_class.active_without_invites_and_requests.to_a }

      it { is_expected.to include @owner }
      it { is_expected.to include @maintainer }
      it { is_expected.not_to include @invited_member }
      it { is_expected.to include @accepted_invite_member }
      it { is_expected.not_to include @requested_member }
      it { is_expected.to include @accepted_request_member }
      it { is_expected.not_to include @blocked_maintainer }
      it { is_expected.not_to include @blocked_developer }
      it { is_expected.not_to include @member_with_minimal_access }
    end

    describe '.without_invites_and_requests' do
      subject { described_class.without_invites_and_requests.to_a }

      it { is_expected.to include @owner }
      it { is_expected.to include @maintainer }
      it { is_expected.not_to include @invited_member }
      it { is_expected.to include @accepted_invite_member }
      it { is_expected.not_to include @requested_member }
      it { is_expected.to include @accepted_request_member }
      it { is_expected.to include @blocked_maintainer }
      it { is_expected.to include @blocked_developer }
      it { is_expected.not_to include @member_with_minimal_access }
      it { is_expected.not_to include awaiting_group_member }
      it { is_expected.not_to include awaiting_project_member }
    end

    describe '.connected_to_user' do
      subject { described_class.connected_to_user.to_a }

      it { is_expected.to include @owner }
      it { is_expected.to include @maintainer }
      it { is_expected.to include @accepted_invite_member }
      it { is_expected.to include @accepted_request_member }
      it { is_expected.to include @blocked_maintainer }
      it { is_expected.to include @blocked_developer }
      it { is_expected.to include @requested_member }
      it { is_expected.to include @member_with_minimal_access }
      it { is_expected.not_to include @invited_member }
    end

    describe '.authorizable' do
      subject { described_class.authorizable.to_a }

      it 'includes the member who has an associated user record,'\
       'but also having an invite_token' do
        member = create(:project_member,
                        :developer,
                        :invited,
                        user: create(:user))

        expect(subject).to include(member)
      end

      it { is_expected.to include @owner }
      it { is_expected.to include @maintainer }
      it { is_expected.to include @accepted_invite_member }
      it { is_expected.to include @accepted_request_member }
      it { is_expected.to include @blocked_maintainer }
      it { is_expected.to include @blocked_developer }
      it { is_expected.not_to include @invited_member }
      it { is_expected.not_to include @requested_member }
      it { is_expected.not_to include @member_with_minimal_access }
      it { is_expected.not_to include awaiting_group_member }
      it { is_expected.not_to include awaiting_project_member }
    end

    describe '.distinct_on_user_with_max_access_level' do
      let_it_be(:other_group) { create(:group) }
      let_it_be(:member_with_lower_access_level) { create(:group_member, :developer, group: other_group, user: @owner_user) }

      subject { described_class.default_scoped.distinct_on_user_with_max_access_level.to_a }

      it { is_expected.not_to include member_with_lower_access_level }
      it { is_expected.to include @owner }
      it { is_expected.to include @maintainer }
      it { is_expected.to include @invited_member }
      it { is_expected.to include @accepted_invite_member }
      it { is_expected.to include @requested_member }
      it { is_expected.to include @accepted_request_member }
      it { is_expected.to include @blocked_maintainer }
      it { is_expected.to include @blocked_developer }
      it { is_expected.to include @member_with_minimal_access }

      context 'with where conditions' do
        let_it_be(:example_member) { create(:group_member, invite_email: 'user@example.com') }

        subject do
          described_class
            .default_scoped
            .where(invite_email: 'user@example.com')
            .distinct_on_user_with_max_access_level
            .to_a
        end

        it { is_expected.to eq [example_member] }
      end
    end

    describe '.with_invited_user_state' do
      subject(:with_invited_user_state) { described_class.with_invited_user_state }

      it { is_expected.to include @owner }
      it { is_expected.to include @maintainer }
      it { is_expected.to include @invited_member }
      it { is_expected.to include @accepted_invite_member }
      it { is_expected.to include @requested_member }
      it { is_expected.to include @accepted_request_member }

      context 'with invited pending members' do
        it 'includes invited user state' do
          invited_pending_members = with_invited_user_state.select { |m| m.invited_user_state.present? }
          expect(invited_pending_members.count).to eq 1
          expect(invited_pending_members).to include blocked_pending_approval_project_member
        end
      end
    end

    describe '.active_state' do
      let_it_be(:active_group_member) { create(:group_member, group: group) }
      let_it_be(:active_project_member) { create(:project_member, project: project) }

      it 'includes members with an active state' do
        expect(group.members.active_state).to include active_group_member
        expect(project.members.active_state).to include active_project_member
      end

      it 'does not include members with an awaiting state' do
        expect(group.members.active_state).not_to include awaiting_group_member
        expect(project.members.active_state).not_to include awaiting_project_member
      end
    end
  end

  describe 'Delegate methods' do
    it { is_expected.to respond_to(:user_name) }
    it { is_expected.to respond_to(:user_email) }
  end

  describe '.valid_email?' do
    it 'is a valid email format' do
      expect(described_class.valid_email?('foo')).to eq(false)
    end

    it 'is not a valid email format' do
      expect(described_class.valid_email?('foo@example.com')).to eq(true)
    end
  end

  describe '#accept_request' do
    let(:member) { create(:project_member, requested_at: Time.current.utc) }

    it { expect(member.accept_request).to be_truthy }

    it 'clears requested_at' do
      member.accept_request

      expect(member.requested_at).to be_nil
    end

    it 'calls #after_accept_request' do
      expect(member).to receive(:after_accept_request)

      member.accept_request
    end
  end

  describe '#invite?' do
    subject { create(:project_member, invite_email: "user@example.com", user: nil) }

    it { is_expected.to be_invite }
  end

  describe '#request?' do
    subject { create(:project_member, requested_at: Time.current.utc) }

    it { is_expected.to be_request }
  end

  describe '#pending?' do
    let(:invited_member) { create(:project_member, invite_email: "user@example.com", user: nil) }
    let(:requester) { create(:project_member, requested_at: Time.current.utc) }

    it { expect(invited_member).to be_pending }
    it { expect(requester).to be_pending }
  end

  describe '#hook_prerequisites_met?' do
    let(:member) { create(:project_member) }

    context 'when the member does not have an associated user' do
      it 'returns false' do
        member.update_column(:user_id, nil)
        expect(member.reload.hook_prerequisites_met?).to eq(false)
      end
    end

    context 'when the member has an associated user' do
      it 'returns true' do
        expect(member.hook_prerequisites_met?).to eq(true)
      end
    end
  end

  describe '#accept_invite!' do
    let!(:member) { create(:project_member, invite_email: "user@example.com", user: nil) }
    let(:user) { create(:user) }

    it 'resets the invite token' do
      member.accept_invite!(user)

      expect(member.invite_token).to be_nil
    end

    it 'sets the invite accepted timestamp' do
      member.accept_invite!(user)

      expect(member.invite_accepted_at).not_to be_nil
    end

    it 'sets the user' do
      member.accept_invite!(user)

      expect(member.user).to eq(user)
    end

    it 'calls #after_accept_invite' do
      expect(member).to receive(:after_accept_invite)

      member.accept_invite!(user)
    end

    context 'authorized projects' do
      let(:project) { member.source }

      before do
        expect(user.authorized_projects).not_to include(project)
      end

      it 'successfully completes a blocking refresh', :delete do
        expect(member).to receive(:refresh_member_authorized_projects).with(blocking: true).and_call_original

        member.accept_invite!(user)

        expect(user.authorized_projects.reload).to include(project)
      end

      it 'successfully completes a non-blocking refresh', :delete, :sidekiq_inline do
        member.blocking_refresh = false

        expect(member).to receive(:refresh_member_authorized_projects).with(blocking: false).and_call_original

        member.accept_invite!(user)

        expect(user.authorized_projects.reload).to include(project)
      end

      context 'when the feature flag is disabled' do
        before do
          stub_feature_flags(allow_non_blocking_member_refresh: false)
        end

        it 'successfully completes a blocking refresh', :delete, :sidekiq_inline do
          member.blocking_refresh = false

          expect(member).to receive(:refresh_member_authorized_projects).with(blocking: true).and_call_original

          member.accept_invite!(user)

          expect(user.authorized_projects.reload).to include(project)
        end
      end
    end

    it 'does not accept the invite if saving a new user fails' do
      invalid_user = User.new(first_name: '', last_name: '')

      member.accept_invite! invalid_user

      expect(member.invite_accepted_at).to be_nil
      expect(member.invite_token).not_to be_nil
      expect_any_instance_of(Member).not_to receive(:after_accept_invite)
    end

    it 'schedules a TasksToBeDone::CreateWorker task' do
      member_task = create(:member_task, member: member, project: member.project)

      expect(TasksToBeDone::CreateWorker)
        .to receive(:perform_async)
        .with(member_task.id, member.created_by_id, [user.id])
        .once

      member.accept_invite!(user)
    end
  end

  describe '#decline_invite!' do
    let!(:member) { create(:project_member, invite_email: "user@example.com", user: nil) }

    it 'destroys the member' do
      member.decline_invite!

      expect(member).to be_destroyed
    end

    it 'calls #after_decline_invite' do
      expect(member).to receive(:after_decline_invite)

      member.decline_invite!
    end
  end

  describe '#generate_invite_token' do
    let!(:member) { create(:project_member, invite_email: "user@example.com", user: nil) }

    it 'sets the invite token' do
      expect { member.generate_invite_token }.to change { member.invite_token }
    end
  end

  describe 'generate invite token on create' do
    let!(:member) { build(:project_member, invite_email: "user@example.com") }

    it 'sets the invite token' do
      expect { member.save! }.to change { member.invite_token }.to(kind_of(String))
    end

    context 'when invite was already accepted' do
      it 'does not set invite token' do
        member.invite_accepted_at = 1.day.ago

        expect { member.save! }.not_to change { member.invite_token }.from(nil)
      end
    end
  end

  describe '.find_by_invite_token' do
    let!(:member) { create(:project_member, invite_email: "user@example.com", user: nil) }

    it 'finds the member' do
      expect(described_class.find_by_invite_token(member.raw_invite_token)).to eq member
    end
  end

  describe '#send_invitation_reminder' do
    subject { member.send_invitation_reminder(0) }

    context 'an invited group member' do
      let!(:member) { create(:group_member, :invited) }

      it 'sends a reminder' do
        expect_any_instance_of(NotificationService).to receive(:invite_member_reminder).with(member, member.raw_invite_token, 0)

        subject
      end
    end

    context 'an invited member without a raw invite token set' do
      let!(:member) { create(:group_member, :invited) }

      before do
        member.instance_variable_set(:@raw_invite_token, nil)
        allow_any_instance_of(NotificationService).to receive(:invite_member_reminder)
      end

      it 'generates a new token' do
        expect(member).to receive(:generate_invite_token!)

        subject
      end
    end

    context 'an uninvited member' do
      let!(:member) { create(:group_member) }

      it 'does not send a reminder' do
        expect_any_instance_of(NotificationService).not_to receive(:invite_member_reminder)

        subject
      end
    end
  end

  describe '#invite_to_unknown_user?' do
    subject { member.invite_to_unknown_user? }

    let(:member) { create(:project_member, invite_email: "user@example.com", invite_token: '1234', user: user) }

    context 'when user is nil' do
      let(:user) { nil }

      it { is_expected.to eq(true) }
    end

    context 'when user is set' do
      let(:user) { build(:user) }

      it { is_expected.to eq(false) }
    end
  end

  describe 'destroying a record', :delete, :sidekiq_inline do
    it "refreshes user's authorized projects" do
      project = create(:project, :private)
      user    = create(:user)
      member  = project.add_reporter(user)

      member.destroy!

      expect(user.authorized_projects).not_to include(project)
    end
  end

  context 'when after_commit :update_highest_role' do
    let_it_be(:user) { create(:user) }

    let(:user_id) { user.id }

    where(:member_type, :source_type) do
      :project_member | :project
      :group_member   | :group
    end

    with_them do
      describe 'create member' do
        let!(:source) { create(source_type) } # rubocop:disable Rails/SaveBang

        subject { create(member_type, :guest, user: user, source: source) }

        include_examples 'update highest role with exclusive lease'
      end

      context 'when member exists' do
        let!(:member) { create(member_type, user: user) }

        describe 'update member' do
          context 'when access level was changed' do
            subject { member.update!(access_level: Gitlab::Access::GUEST) }

            include_examples 'update highest role with exclusive lease'
          end

          context 'when access level was not changed' do
            subject { member.update!(notification_level: NotificationSetting.levels[:disabled]) }

            include_examples 'does not update the highest role'
          end
        end

        describe 'destroy member' do
          subject { member.reload.destroy! }

          include_examples 'update highest role with exclusive lease'
        end
      end
    end
  end

  describe 'log_invitation_token_cleanup' do
    let_it_be(:project) { create :project }

    context 'when on gitlab.com' do
      before do
        allow(Gitlab).to receive(:com?).and_return true
      end

      it "doesn't log info for members without invitation or accepted invitation" do
        expect(Gitlab::ErrorTracking).not_to receive(:track_exception)

        create :project_member
        create :project_member, :invited, invite_accepted_at: nil
        create :project_member, invite_token: nil, invite_accepted_at: Time.zone.now
      end

      it 'logs error for accepted members with token and creates membership' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(kind_of(StandardError), kind_of(Hash))

        expect do
          create :project_member, :invited, source: project, invite_accepted_at: Time.zone.now
        end.to change { Member.count }.by(1)
      end
    end

    context 'when not on gitlab.com' do
      before do
        allow(Gitlab).to receive(:com?).and_return false
      end

      it 'does not log error for accepted members with token and creates membership' do
        expect(Gitlab::ErrorTracking).not_to receive(:track_exception)

        expect do
          create :project_member, :invited, source: project, invite_accepted_at: Time.zone.now
        end.to change { Member.count }.by(1)
      end
    end
  end

  describe '#set_member_namespace_id' do
    let(:group) { create(:group) }
    let(:member) { create(:group_member, group: group) }

    describe 'on create' do
      it 'sets the member_namespace_id' do
        expect(member.member_namespace_id).to eq group.id
      end
    end
  end

  describe '.sort_by_attribute' do
    let_it_be(:user1) { create(:user, created_at: Date.today, last_sign_in_at: Date.today, last_activity_on: Date.today, name: 'Alpha') }
    let_it_be(:user2) { create(:user, created_at: Date.today - 1, last_sign_in_at: Date.today - 1, last_activity_on: Date.today - 1, name: 'Omega') }
    let_it_be(:user3) { create(:user, created_at: Date.today - 2, name: 'Beta') }
    let_it_be(:group) { create(:group) }
    let_it_be(:member1) { create(:group_member, :reporter, group: group, user: user1) }
    let_it_be(:member2) { create(:group_member, :developer, group: group, user: user2) }
    let_it_be(:member3) { create(:group_member, :maintainer, group: group, user: user3) }

    it 'sort users in ascending order by access-level' do
      expect(described_class.sort_by_attribute('access_level_asc')).to eq([member1, member2, member3])
    end

    it 'sort users in descending order by access-level' do
      expect(described_class.sort_by_attribute('access_level_desc')).to eq([member3, member2, member1])
    end

    context 'when sort by recent_sign_in' do
      subject { described_class.sort_by_attribute('recent_sign_in') }

      it 'sorts users by recent sign-in time' do
        expect(subject.first).to eq(member1)
        expect(subject.second).to eq(member2)
      end

      it 'pushes users who never signed in to the end' do
        expect(subject.third).to eq(member3)
      end
    end

    context 'when sort by oldest_sign_in' do
      subject { described_class.sort_by_attribute('oldest_sign_in') }

      it 'sorts users by the oldest sign-in time' do
        expect(subject.first).to eq(member2)
        expect(subject.second).to eq(member1)
      end

      it 'pushes users who never signed in to the end' do
        expect(subject.third).to eq(member3)
      end
    end

    it 'sorts users in descending order by their creation time' do
      expect(described_class.sort_by_attribute('recent_created_user')).to eq([member1, member2, member3])
    end

    it 'sorts users in ascending order by their creation time' do
      expect(described_class.sort_by_attribute('oldest_created_user')).to eq([member3, member2, member1])
    end

    it 'sort users by recent last activity' do
      expect(described_class.sort_by_attribute('recent_last_activity')).to eq([member1, member2, member3])
    end

    it 'sort users by oldest last activity' do
      expect(described_class.sort_by_attribute('oldest_last_activity')).to eq([member3, member2, member1])
    end
  end
end
