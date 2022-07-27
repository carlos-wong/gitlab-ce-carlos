# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Autocomplete::UsersFinder do
  # TODO update when multiple owners are possible in projects
  # https://gitlab.com/gitlab-org/gitlab/-/issues/21432

  describe '#execute' do
    let_it_be(:user1) { create(:user, name: 'zzzzzname', username: 'johndoe') }
    let_it_be(:user2) { create(:user, :blocked, username: 'notsorandom') }
    let_it_be(:external_user) { create(:user, :external) }
    let_it_be(:omniauth_user) { create(:omniauth_user, provider: 'twitter', extern_uid: '123456') }

    let(:current_user) { create(:user) }
    let(:params) { {} }

    let_it_be(:project) { nil }
    let_it_be(:group) { nil }

    subject { described_class.new(params: params, current_user: current_user, project: project, group: group).execute.to_a }

    context 'when current_user not passed or nil' do
      let(:current_user) { nil }

      it { is_expected.to match_array([]) }
    end

    context 'when project passed' do
      let_it_be(:project) { create(:project) }

      it { is_expected.to match_array([project.first_owner]) }

      context 'when author_id passed' do
        context 'and author is active' do
          let(:params) { { author_id: user1.id } }

          it { is_expected.to match_array([project.first_owner, user1]) }
        end

        context 'and author is blocked' do
          let(:params) { { author_id: user2.id } }

          it { is_expected.to match_array([project.first_owner]) }
        end
      end

      context 'searching with less than 3 characters' do
        let(:params) { { search: 'zz' } }

        before do
          project.add_guest(user1)
        end

        it 'allows partial matches' do
          expect(subject).to contain_exactly(user1)
        end
      end
    end

    context 'when group passed and project not passed' do
      let_it_be(:group) { create(:group, :public) }

      before_all do
        group.add_members([user1], GroupMember::DEVELOPER)
      end

      it { is_expected.to match_array([user1]) }

      context 'searching with less than 3 characters' do
        let(:params) { { search: 'zz' } }

        it 'allows partial matches' do
          expect(subject).to contain_exactly(user1)
        end
      end
    end

    context 'when passed a subgroup' do
      let(:grandparent) { create(:group, :public) }
      let(:parent) { create(:group, :public, parent: grandparent) }
      let(:child) { create(:group, :public, parent: parent) }
      let(:group) { parent }

      let!(:grandparent_user) { create(:group_member, :developer, group: grandparent).user }
      let!(:parent_user) { create(:group_member, :developer, group: parent).user }
      let!(:child_user) { create(:group_member, :developer, group: child).user }

      it 'includes users from parent groups as well' do
        expect(subject).to match_array([grandparent_user, parent_user])
      end
    end

    it { is_expected.to match_array([user1, external_user, omniauth_user, current_user]) }

    context 'when filtered by search' do
      let(:params) { { search: 'johndoe' } }

      it { is_expected.to match_array([user1]) }

      context 'searching with less than 3 characters' do
        let(:params) { { search: 'zz' } }

        it 'does not allow partial matches' do
          expect(subject).to be_empty
        end
      end
    end

    context 'when filtered by skip_users' do
      let(:params) { { skip_users: [omniauth_user.id, current_user.id] } }

      it { is_expected.to match_array([user1, external_user]) }
    end

    context 'when todos exist' do
      let!(:pending_todo1) { create(:todo, user: current_user, author: user1, state: :pending) }
      let!(:pending_todo2) { create(:todo, user: external_user, author: omniauth_user, state: :pending) }
      let!(:done_todo1) { create(:todo, user: current_user, author: external_user, state: :done) }
      let!(:done_todo2) { create(:todo, user: user1, author: external_user, state: :done) }

      context 'when filtered by todo_filter without todo_state_filter' do
        let(:params) { { todo_filter: true } }

        it { is_expected.to match_array([]) }
      end

      context 'when filtered by todo_filter with pending todo_state_filter' do
        let(:params) { { todo_filter: true, todo_state_filter: 'pending' } }

        it { is_expected.to match_array([user1]) }
      end

      context 'when filtered by todo_filter with done todo_state_filter' do
        let(:params) { { todo_filter: true, todo_state_filter: 'done' } }

        it { is_expected.to match_array([external_user]) }
      end
    end

    context 'when filtered by current_user' do
      let(:current_user) { user2 }
      let(:params) { { current_user: true } }

      it { is_expected.to match_array([user2, user1, external_user, omniauth_user]) }
    end

    context 'when filtered by author_id' do
      let(:params) { { author_id: user1.id } }

      it { is_expected.to match_array([user1, external_user, omniauth_user, current_user]) }
    end

    it 'preloads the status association' do
      associations = subject.map { |user| user.association(:status) }
      expect(associations).to all(be_loaded)
    end
  end
end
