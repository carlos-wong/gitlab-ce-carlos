# frozen_string_literal: true

require 'spec_helper'

describe Resolvers::MilestoneResolver do
  include GraphqlHelpers

  describe '#resolve' do
    let_it_be(:current_user) { create(:user) }

    context 'for group milestones' do
      let_it_be(:now) { Time.now }
      let_it_be(:group) { create(:group, :private) }

      def resolve_group_milestones(args = {}, context = { current_user: current_user })
        resolve(described_class, obj: group, args: args, ctx: context)
      end

      before do
        group.add_developer(current_user)
      end

      it 'calls MilestonesFinder#execute' do
        expect_next_instance_of(MilestonesFinder) do |finder|
          expect(finder).to receive(:execute)
        end

        resolve_group_milestones
      end

      context 'without parameters' do
        it 'calls MilestonesFinder to retrieve all milestones' do
          expect(MilestonesFinder).to receive(:new)
            .with(group_ids: group.id, state: 'all', start_date: nil, end_date: nil)
            .and_call_original

          resolve_group_milestones
        end
      end

      context 'with parameters' do
        it 'calls MilestonesFinder with correct parameters' do
          start_date = now
          end_date = start_date + 1.hour

          expect(MilestonesFinder).to receive(:new)
            .with(group_ids: group.id, state: 'closed', start_date: start_date, end_date: end_date)
            .and_call_original

          resolve_group_milestones(start_date: start_date, end_date: end_date, state: 'closed')
        end
      end

      context 'by timeframe' do
        context 'when start_date and end_date are present' do
          context 'when start date is after end_date' do
            it 'raises error' do
              expect do
                resolve_group_milestones(start_date: now, end_date: now - 2.days)
              end.to raise_error(Gitlab::Graphql::Errors::ArgumentError, "startDate is after endDate")
            end
          end
        end

        context 'when only start_date is present' do
          it 'raises error' do
            expect do
              resolve_group_milestones(start_date: now)
            end.to raise_error(Gitlab::Graphql::Errors::ArgumentError, /Both startDate and endDate/)
          end
        end

        context 'when only end_date is present' do
          it 'raises error' do
            expect do
              resolve_group_milestones(end_date: now)
            end.to raise_error(Gitlab::Graphql::Errors::ArgumentError, /Both startDate and endDate/)
          end
        end
      end

      context 'when user cannot read milestones' do
        it 'raises error' do
          unauthorized_user = create(:user)

          expect do
            resolve_group_milestones({}, { current_user: unauthorized_user })
          end.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end
    end
  end
end
