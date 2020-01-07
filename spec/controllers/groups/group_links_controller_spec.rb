# frozen_string_literal: true

require 'spec_helper'

describe Groups::GroupLinksController do
  let(:shared_with_group) { create(:group, :private) }
  let(:shared_group) { create(:group, :private) }
  let(:user) { create(:user) }

  before do
    sign_in(user)
  end

  describe '#create' do
    let(:shared_with_group_id) { shared_with_group.id }

    subject do
      post(:create,
           params: { group_id: shared_group,
                     shared_with_group_id: shared_with_group_id,
                     shared_group_access: GroupGroupLink.default_access })
    end

    context 'when user has correct access to both groups' do
      let(:group_member) { create(:user) }

      before do
        shared_with_group.add_developer(user)
        shared_group.add_owner(user)

        shared_with_group.add_developer(group_member)
      end

      it 'links group with selected group' do
        expect { subject }.to change { shared_with_group.shared_groups.include?(shared_group) }.from(false).to(true)
      end

      it 'redirects to group links page' do
        subject

        expect(response).to(redirect_to(group_group_members_path(shared_group)))
      end

      it 'allows access for group member' do
        expect { subject }.to change { group_member.can?(:read_group, shared_group) }.from(false).to(true)
      end

      context 'when shared with group id is not present' do
        let(:shared_with_group_id) { nil }

        it 'redirects to group links page' do
          subject

          expect(response).to(redirect_to(group_group_members_path(shared_group)))
          expect(flash[:alert]).to eq('Please select a group.')
        end
      end

      context 'when link is not persisted in the database' do
        before do
          allow(::Groups::GroupLinks::CreateService).to(
            receive_message_chain(:new, :execute)
              .and_return({ status: :error,
                            http_status: 409,
                            message: 'error' }))
        end

        it 'redirects to group links page' do
          subject

          expect(response).to(redirect_to(group_group_members_path(shared_group)))
          expect(flash[:alert]).to eq('error')
        end
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(share_group_with_group: false)
        end

        it 'renders 404' do
          subject

          expect(response).to have_gitlab_http_status(404)
        end
      end
    end

    context 'when user does not have access to the group' do
      before do
        shared_group.add_owner(user)
      end

      it 'renders 404' do
        subject

        expect(response).to have_gitlab_http_status(404)
      end
    end

    context 'when user does not have admin access to the shared group' do
      before do
        shared_with_group.add_developer(user)
        shared_group.add_developer(user)
      end

      it 'renders 404' do
        subject

        expect(response).to have_gitlab_http_status(404)
      end
    end
  end
end
