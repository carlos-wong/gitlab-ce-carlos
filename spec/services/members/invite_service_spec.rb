# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::InviteService, :aggregate_failures, :clean_gitlab_redis_shared_state, :sidekiq_inline do
  let_it_be(:project, reload: true) { create(:project) }
  let_it_be(:user) { project.first_owner }
  let_it_be(:project_user) { create(:user) }
  let_it_be(:user_invited_by_id) { create(:user) }
  let_it_be(:namespace) { project.namespace }

  let(:params) { {} }
  let(:base_params) { { access_level: Gitlab::Access::GUEST, source: project, invite_source: '_invite_source_' } }

  subject(:result) { described_class.new(user, base_params.merge(params) ).execute }

  context 'when there is a valid member invited' do
    let(:params) { { email: 'email@example.org' } }

    it 'successfully creates a member' do
      expect_to_create_members(count: 1)
      expect(result[:status]).to eq(:success)
    end

    it_behaves_like 'records an onboarding progress action', :user_added

    it 'does not create task issues' do
      expect(TasksToBeDone::CreateWorker).not_to receive(:perform_async)
      expect { result }.not_to change { project.issues.count }
    end
  end

  context 'when email belongs to an existing user as a secondary email' do
    let(:secondary_email) { create(:email, email: 'secondary@example.com', user: project_user) }
    let(:params) { { email: secondary_email.email } }

    it 'adds an existing user to members', :aggregate_failures do
      expect_to_create_members(count: 1)
      expect(result[:status]).to eq(:success)
      expect(project.users).to include project_user
      expect(project.members.last).not_to be_invite
    end
  end

  context 'when invites are passed as array' do
    context 'with emails' do
      let(:params) { { email: %w[email@example.org email2@example.org] } }

      it 'successfully creates members' do
        expect_to_create_members(count: 2)
        expect(result[:status]).to eq(:success)
      end
    end

    context 'with user_id as integers' do
      let(:params) { { user_id: [project_user.id, user_invited_by_id.id] } }

      it 'successfully creates members' do
        expect_to_create_members(count: 2)
        expect(result[:status]).to eq(:success)
      end
    end

    context 'with user_id as strings' do
      let(:params) { { user_id: [project_user.id.to_s, user_invited_by_id.id.to_s] } }

      it 'successfully creates members' do
        expect_to_create_members(count: 2)
        expect(result[:status]).to eq(:success)
      end
    end

    context 'with a mixture of emails and user_id' do
      let(:params) do
        { user_id: [project_user.id, user_invited_by_id.id], email: %w[email@example.org email2@example.org] }
      end

      it 'successfully creates members' do
        expect_to_create_members(count: 4)
        expect(result[:status]).to eq(:success)
      end
    end
  end

  context 'with multiple invites passed as strings' do
    context 'with emails' do
      let(:params) { { email: 'email@example.org,email2@example.org' } }

      it 'successfully creates members' do
        expect_to_create_members(count: 2)
        expect(result[:status]).to eq(:success)
      end
    end

    context 'with user_id' do
      let(:params) { { user_id: "#{project_user.id},#{user_invited_by_id.id}" } }

      it 'successfully creates members' do
        expect_to_create_members(count: 2)
        expect(result[:status]).to eq(:success)
      end
    end

    context 'with a mixture of emails and user_id' do
      let(:params) do
        { user_id: "#{project_user.id},#{user_invited_by_id.id}", email: 'email@example.org,email2@example.org' }
      end

      it 'successfully creates members' do
        expect_to_create_members(count: 4)
        expect(result[:status]).to eq(:success)
      end
    end
  end

  context 'when invites formats are mixed' do
    context 'when user_id is an array and emails is a string' do
      let(:params) do
        { user_id: [project_user.id, user_invited_by_id.id], email: 'email@example.org,email2@example.org' }
      end

      it 'successfully creates members' do
        expect_to_create_members(count: 4)
        expect(result[:status]).to eq(:success)
      end
    end

    context 'when user_id is a string and emails is an array' do
      let(:params) do
        { user_id: "#{project_user.id},#{user_invited_by_id.id}", email: %w[email@example.org email2@example.org] }
      end

      it 'successfully creates members' do
        expect_to_create_members(count: 4)
        expect(result[:status]).to eq(:success)
      end
    end
  end

  context 'when invites are passed in different formats' do
    context 'when emails are passed as an empty string' do
      let(:params) { { email: '' } }

      it 'returns an error' do
        expect_not_to_create_members
        expect(result[:message]).to eq('Invites cannot be blank')
      end
    end

    context 'when user_id are passed as an empty string' do
      let(:params) { { user_id: '' } }

      it 'returns an error' do
        expect_not_to_create_members
        expect(result[:message]).to eq('Invites cannot be blank')
      end
    end

    context 'when user_id and emails are both passed as empty strings' do
      let(:params) { { user_id: '', email: '' } }

      it 'returns an error' do
        expect_not_to_create_members
        expect(result[:message]).to eq('Invites cannot be blank')
      end
    end

    context 'when user_id is passed as an integer' do
      let(:params) { { user_id: project_user.id } }

      it 'successfully creates member' do
        expect_to_create_members(count: 1)
        expect(result[:status]).to eq(:success)
      end
    end

    context 'when invite params are not included' do
      it 'returns an error' do
        expect_not_to_create_members
        expect(result[:message]).to eq('Invites cannot be blank')
      end
    end
  end

  context 'when email is not a valid email format' do
    context 'with singular email' do
      let(:params) { { email: '_bogus_' } }

      it 'returns an error' do
        expect_not_to_create_members
        expect(result[:status]).to eq(:error)
        expect(result[:message][params[:email]]).to eq("Invite email is invalid")
      end

      it_behaves_like 'does not record an onboarding progress action'
    end

    context 'with user_id and singular invalid email' do
      let(:params) { { user_id: project_user.id, email: '_bogus_' } }

      it 'has partial success' do
        expect_to_create_members(count: 1)
        expect(project.users).to include project_user

        expect(result[:status]).to eq(:error)
        expect(result[:message][params[:email]]).to eq("Invite email is invalid")
      end
    end
  end

  context 'with duplicate invites' do
    context 'with duplicate emails' do
      let(:params) { { email: 'email@example.org,email@example.org' } }

      it 'only creates one member per unique invite' do
        expect_to_create_members(count: 1)
        expect(result[:status]).to eq(:success)
      end
    end

    context 'with duplicate user ids' do
      let(:params) { { user_id: "#{project_user.id},#{project_user.id}" } }

      it 'only creates one member per unique invite' do
        expect_to_create_members(count: 1)
        expect(result[:status]).to eq(:success)
      end
    end

    context 'with duplicate member by adding as user id and email' do
      let(:params) { { user_id: project_user.id, email: project_user.email } }

      it 'only creates one member per unique invite' do
        expect_to_create_members(count: 1)
        expect(result[:status]).to eq(:success)
      end
    end
  end

  context 'when observing invite limits' do
    context 'with emails and in general' do
      let_it_be(:emails) { Array(1..101).map { |n| "email#{n}@example.com" } }

      context 'when over the allowed default limit of emails' do
        let(:params) { { email: emails } }

        it 'limits the number of emails to 100' do
          expect_not_to_create_members
          expect(result[:message]).to eq('Too many users specified (limit is 100)')
        end
      end

      context 'when over the allowed custom limit of emails' do
        let(:params) { { email: 'email@example.org,email2@example.org', limit: 1 } }

        it 'limits the number of emails to the limit supplied' do
          expect_not_to_create_members
          expect(result[:message]).to eq('Too many users specified (limit is 1)')
        end
      end

      context 'when limit allowed is disabled via limit param' do
        let(:params) { { email: emails, limit: -1 } }

        it 'does not limit number of emails' do
          expect_to_create_members(count: 101)
          expect(result[:status]).to eq(:success)
        end
      end
    end

    context 'with user_id' do
      let(:user_id) { 1.upto(101).to_a.join(',') }
      let(:params) { { user_id: user_id } }

      it 'limits the number of users to 100' do
        expect_not_to_create_members
        expect(result[:message]).to eq('Too many users specified (limit is 100)')
      end
    end
  end

  context 'with an existing user' do
    context 'with email' do
      let(:params) { { email: project_user.email } }

      it 'adds an existing user to members' do
        expect_to_create_members(count: 1)
        expect(result[:status]).to eq(:success)
        expect(project.users).to include project_user
      end
    end

    context 'with user_id' do
      let(:params) { { user_id: project_user.id } }

      it_behaves_like 'records an onboarding progress action', :user_added

      it 'adds an existing user to members' do
        expect_to_create_members(count: 1)
        expect(result[:status]).to eq(:success)
        expect(project.users).to include project_user
      end

      context 'when assigning tasks to be done' do
        let(:params) do
          { user_id: project_user.id, tasks_to_be_done: %w(ci code), tasks_project_id: project.id }
        end

        it 'creates 2 task issues', :aggregate_failures do
          expect(TasksToBeDone::CreateWorker)
            .to receive(:perform_async)
                  .with(anything, user.id, [project_user.id])
                  .once
                  .and_call_original
          expect { result }.to change { project.issues.count }.by(2)

          expect(project.issues).to all have_attributes(project: project, author: user)
        end
      end
    end
  end

  context 'when access level is not valid' do
    context 'with email' do
      let(:params) { { email: project_user.email, access_level: -1 } }

      it 'returns an error' do
        expect_not_to_create_members
        expect(result[:message][project_user.email]).to eq("Access level is not included in the list")
      end
    end

    context 'with user_id' do
      let(:params) { { user_id: user_invited_by_id.id, access_level: -1 } }

      it 'returns an error' do
        expect_not_to_create_members
        expect(result[:message][user_invited_by_id.username]).to eq("Access level is not included in the list")
      end
    end

    context 'with a mix of user_id and email' do
      let(:params) { { user_id: user_invited_by_id.id, email: project_user.email, access_level: -1 } }

      it 'returns errors' do
        expect_not_to_create_members
        expect(result[:message][project_user.email]).to eq("Access level is not included in the list")
        expect(result[:message][user_invited_by_id.username]).to eq("Access level is not included in the list")
      end
    end
  end

  context 'when member already exists' do
    context 'with email' do
      let!(:invited_member) { create(:project_member, :guest, :invited, project: project) }
      let(:params) do
        { email: "#{invited_member.invite_email},#{project_user.email}", access_level: ProjectMember::MAINTAINER }
      end

      it 'adds new email and allows already invited members to be re-invited by email and updates the member access' do
        expect_to_create_members(count: 1)
        expect(result[:status]).to eq(:success)
        expect(project.users).to include project_user
        expect(invited_member.reset.access_level).to eq ProjectMember::MAINTAINER
      end
    end

    context 'when email is already a member with a user on the project' do
      let!(:existing_member) { create(:project_member, :guest, project: project) }
      let(:params) { { email: "#{existing_member.user.email}", access_level: ProjectMember::MAINTAINER } }

      it 'allows re-invite of an already invited email and updates the access_level' do
        expect { result }.not_to change(ProjectMember, :count)
        expect(result[:status]).to eq(:success)
        expect(existing_member.reset.access_level).to eq ProjectMember::MAINTAINER
      end

      context 'when email belongs to an existing user as a secondary email' do
        let(:secondary_email) { create(:email, email: 'secondary@example.com', user: existing_member.user) }
        let(:params) { { email: "#{secondary_email.email}" } }

        it 'allows re-invite to an already invited email' do
          expect_to_create_members(count: 0)
          expect(result[:status]).to eq(:success)
        end
      end
    end

    context 'with user_id that already exists' do
      let!(:existing_member) { create(:project_member, project: project, user: project_user) }
      let(:params) { { user_id: existing_member.user_id } }

      it 'does not add the member again and is successful' do
        expect_to_create_members(count: 0)
        expect(project.users).to include project_user
      end
    end

    context 'with user_id that already exists with a lower access_level' do
      let!(:existing_member) { create(:project_member, :developer, project: project, user: project_user) }
      let(:params) { { user_id: existing_member.user_id, access_level: ProjectMember::MAINTAINER } }

      it 'does not add the member again and updates the access_level' do
        expect_to_create_members(count: 0)
        expect(project.users).to include project_user
        expect(existing_member.reset.access_level).to eq ProjectMember::MAINTAINER
      end
    end

    context 'with user_id that already exists with a higher access_level' do
      let!(:existing_member) { create(:project_member, :developer, project: project, user: project_user) }
      let(:params) { { user_id: existing_member.user_id, access_level: ProjectMember::GUEST } }

      it 'does not add the member again and updates the access_level' do
        expect_to_create_members(count: 0)
        expect(project.users).to include project_user
        expect(existing_member.reset.access_level).to eq ProjectMember::GUEST
      end
    end

    context 'with user_id that already exists in a parent group' do
      let_it_be(:group) { create(:group) }
      let_it_be(:group_member) { create(:group_member, :developer, source: group, user: project_user) }
      let_it_be(:project, reload: true) { create(:project, group: group) }
      let_it_be(:user) { project.creator }

      before_all do
        project.add_maintainer(user)
      end

      context 'when access_level is lower than inheriting member' do
        let(:params) { { user_id: group_member.user_id, access_level: ProjectMember::GUEST }}

        it 'does not add the member and returns an error' do
          msg = "Access level should be greater than or equal " \
                "to Developer inherited membership from group #{group.name}"

          expect_not_to_create_members
          expect(result[:message][project_user.username]).to eq msg
        end
      end

      context 'when access_level is the same as the inheriting member' do
        let(:params) { { user_id: group_member.user_id, access_level: ProjectMember::DEVELOPER }}

        it 'adds the member with correct access_level' do
          expect_to_create_members(count: 1)
          expect(project.users).to include project_user
          expect(project.project_members.last.access_level).to eq ProjectMember::DEVELOPER
        end
      end

      context 'when access_level is greater than the inheriting member' do
        let(:params) { { user_id: group_member.user_id, access_level: ProjectMember::MAINTAINER }}

        it 'adds the member with correct access_level' do
          expect_to_create_members(count: 1)
          expect(project.users).to include project_user
          expect(project.project_members.last.access_level).to eq ProjectMember::MAINTAINER
        end
      end
    end
  end

  def expect_to_create_members(count:)
    expect { result }.to change(ProjectMember, :count).by(count)
  end

  def expect_not_to_create_members
    expect { result }.not_to change(ProjectMember, :count)
    expect(result[:status]).to eq(:error)
  end
end
