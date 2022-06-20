# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::SavedReplies::Destroy do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:saved_reply) { create(:saved_reply, user: current_user) }

  let(:mutation) { described_class.new(object: nil, context: { current_user: current_user }, field: nil) }

  describe '#resolve' do
    subject(:resolve) do
      mutation.resolve(id: saved_reply.to_global_id)
    end

    context 'when feature is disabled' do
      before do
        stub_feature_flags(saved_replies: false)
      end

      it 'raises Gitlab::Graphql::Errors::ResourceNotAvailable' do
        expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable, 'Feature disabled')
      end
    end

    context 'when feature is enabled for current user' do
      before do
        stub_feature_flags(saved_replies: current_user)
      end

      context 'when service fails to delete a new saved reply' do
        before do
          saved_reply.destroy!
        end

        it 'raises Gitlab::Graphql::Errors::ResourceNotAvailable' do
          expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when service successfully deletes the saved reply' do
        it { expect(subject[:errors]).to be_empty }
      end
    end
  end
end
