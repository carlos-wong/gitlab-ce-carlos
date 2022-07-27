# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::InviteMemberBuilder do
  let_it_be(:source) { create(:group) }
  let_it_be(:existing_member) { create(:group_member) }

  let(:existing_members) { { existing_member.user.id => existing_member } }

  describe '#execute' do
    context 'when user record found by email' do
      it 'returns member from existing members hash' do
        expect(described_class.new(source, existing_member.user.email, existing_members).execute).to eq existing_member
      end

      it 'builds a new member' do
        user = create(:user)

        member = described_class.new(source, user.email, existing_members).execute

        expect(member).to be_new_record
        expect(member.user).to eq user
      end
    end
  end

  context 'when no existing users found by the email' do
    it 'finds existing member' do
      member = create(:group_member, :invited, source: source)

      expect(described_class.new(source, member.invite_email, existing_members).execute).to eq member
    end

    it 'builds a new member' do
      email = 'test@example.com'

      member = described_class.new(source, email, existing_members).execute

      expect(member).to be_new_record
      expect(member.invite_email).to eq email
    end
  end
end
