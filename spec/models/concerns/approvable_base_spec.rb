# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovableBase do
  let(:merge_request) { create(:merge_request) }
  let(:user) { create(:user) }

  describe '#approved_by?' do
    subject { merge_request.approved_by?(user) }

    context 'when a user has not approved' do
      it 'returns false' do
        is_expected.to be_falsy
      end
    end

    context 'when a user has approved' do
      let!(:approval) { create(:approval, merge_request: merge_request, user: user) }

      it 'returns false' do
        is_expected.to be_truthy
      end
    end

    context 'when a user is nil' do
      let(:user) { nil }

      it 'returns false' do
        is_expected.to be_falsy
      end
    end
  end

  describe '#can_be_approved_by?' do
    subject { merge_request.can_be_approved_by?(user) }

    before do
      merge_request.project.add_developer(user) if user
    end

    it 'returns true' do
      is_expected.to be_truthy
    end

    context 'when a user has approved' do
      let!(:approval) { create(:approval, merge_request: merge_request, user: user) }

      it 'returns false' do
        is_expected.to be_falsy
      end
    end

    context 'when a user is nil' do
      let(:user) { nil }

      it 'returns false' do
        is_expected.to be_falsy
      end
    end
  end

  describe '#can_be_unapproved_by?' do
    subject { merge_request.can_be_unapproved_by?(user) }

    before do
      merge_request.project.add_developer(user) if user
    end

    it 'returns false' do
      is_expected.to be_falsy
    end

    context 'when a user has approved' do
      let!(:approval) { create(:approval, merge_request: merge_request, user: user) }

      it 'returns true' do
        is_expected.to be_truthy
      end
    end

    context 'when a user is nil' do
      let(:user) { nil }

      it 'returns false' do
        is_expected.to be_falsy
      end
    end
  end

  describe '.not_approved_by_users_with_usernames' do
    subject { MergeRequest.not_approved_by_users_with_usernames([user.username, user2.username]) }

    let!(:merge_request2) { create(:merge_request) }
    let!(:merge_request3) { create(:merge_request) }
    let!(:merge_request4) { create(:merge_request) }
    let(:user2) { create(:user) }
    let(:user3) { create(:user) }

    before do
      create(:approval, merge_request: merge_request, user: user)
      create(:approval, merge_request: merge_request2, user: user2)
      create(:approval, merge_request: merge_request2, user: user3)
      create(:approval, merge_request: merge_request4, user: user3)
    end

    it 'has the merge request that is not approved at all and not approved by either user' do
      expect(subject).to contain_exactly(merge_request3, merge_request4)
    end
  end
end
