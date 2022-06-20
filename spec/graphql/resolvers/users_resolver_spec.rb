# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::UsersResolver do
  include GraphqlHelpers

  let_it_be(:user1) { create(:user, name: "SomePerson") }
  let_it_be(:user2) { create(:user, username: "someone123784") }
  let_it_be(:current_user) { create(:user) }

  specify do
    expect(described_class).to have_nullable_graphql_type(Types::UserType.connection_type)
  end

  describe '#resolve' do
    it 'generates an error when read_users_list is not authorized' do
      expect(Ability).to receive(:allowed?).with(current_user, :read_users_list).and_return(false)

      expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
        resolve_users
      end
    end

    context 'when no arguments are passed' do
      it 'returns all users' do
        expect(resolve_users).to contain_exactly(user1, user2, current_user)
      end
    end

    context 'when both ids and usernames are passed ' do
      it 'generates an error' do
        expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ArgumentError) do
          resolve_users( args: { ids: [user1.to_global_id.to_s], usernames: [user1.username] } )
        end
      end
    end

    context 'when a set of IDs is passed' do
      it 'returns those users' do
        expect(
          resolve_users( args: { ids: [user1.to_global_id.to_s, user2.to_global_id.to_s] } )
        ).to contain_exactly(user1, user2)
      end
    end

    context 'when a set of usernames is passed' do
      it 'returns those users' do
        expect(
          resolve_users( args: { usernames: [user1.username, user2.username] } )
        ).to contain_exactly(user1, user2)
      end
    end

    context 'when admins is true', :enable_admin_mode do
      let(:admin_user) { create(:user, :admin) }

      it 'returns only admins' do
        expect(
          resolve_users( args: { admins: true }, ctx: { current_user: admin_user } )
        ).to contain_exactly(admin_user)
      end
    end

    context 'when a search term is passed' do
      it 'returns all users who match', :aggregate_failures do
        expect(resolve_users( args: { search: "some" } )).to contain_exactly(user1, user2)
        expect(resolve_users( args: { search: "123784" } )).to contain_exactly(user2)
        expect(resolve_users( args: { search: "someperson" } )).to contain_exactly(user1)
      end
    end

    context 'with anonymous access' do
      let_it_be(:current_user) { nil }

      it 'prohibits search without usernames passed' do
        expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
          resolve_users
        end
      end

      it 'allows to search by username' do
        expect(resolve_users(args: { usernames: [user1.username] })).to contain_exactly(user1)
      end
    end
  end

  def resolve_users(args: {}, ctx: {})
    resolve(described_class, args: args, ctx: { current_user: current_user }.merge(ctx))
  end
end
