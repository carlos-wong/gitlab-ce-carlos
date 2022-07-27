# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UnnestedInFilters::Rewriter do
  let(:rewriter) { described_class.new(relation) }

  before(:all) do
    User.include(UnnestedInFilters::Dsl)
  end

  describe '#rewrite?' do
    subject(:rewrite?) { rewriter.rewrite? }

    context 'when the given relation does not have an `IN` predicate' do
      let(:relation) { User.where(username: 'user') }

      it { is_expected.to be_falsey }
    end

    context 'when the given relation has an `IN` predicate' do
      context 'when there is no index coverage for the used columns' do
        let(:relation) { User.where(username: %w(user_1 user_2), state: :active) }

        it { is_expected.to be_falsey }
      end

      context 'when there is an index coverage for the used columns' do
        let(:relation) { User.where(state: :active, user_type: [:support_bot, :alert_bot]) }

        it { is_expected.to be_truthy }

        context 'when there is an ordering' do
          let(:relation) { User.where(state: %w(active blocked banned)).order(order).limit(2) }

          context 'when the order is an Arel node' do
            let(:order) { { user_type: :desc } }

            it { is_expected.to be_truthy }
          end

          context 'when the order is a Keyset order' do
            let(:order) do
              Gitlab::Pagination::Keyset::Order.build([
                Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
                  attribute_name: 'user_type',
                  order_expression: User.arel_table['user_type'].desc,
                  nullable: :not_nullable,
                  distinct: false
                )
              ])
            end

            it { is_expected.to be_truthy }
          end
        end
      end
    end
  end

  describe '#rewrite' do
    let(:recorded_queries) { ActiveRecord::QueryRecorder.new { rewriter.rewrite.load } }
    let(:relation) { User.where(state: :active, user_type: %i(support_bot alert_bot)).limit(2) }

    let(:expected_query) do
      <<~SQL
        SELECT
          "users".*
        FROM
          unnest('{1,2}'::smallint[]) AS "user_types"("user_type"),
          LATERAL (
            SELECT
              "users".*
            FROM
              "users"
            WHERE
              "users"."state" = 'active' AND
              (users."user_type" = "user_types"."user_type")
            LIMIT 2
          ) AS users
        LIMIT 2
      SQL
    end

    subject(:issued_query) { recorded_queries.occurrences.each_key.first }

    it 'changes the query' do
      expect(issued_query.gsub(/\s/, '')).to start_with(expected_query.gsub(/\s/, ''))
    end

    context 'when there is an order' do
      let(:relation) { User.where(state: %w(active blocked banned)).order(order).limit(2) }
      let(:expected_query) do
        <<~SQL
          SELECT
            "users".*
          FROM
            unnest('{active,blocked,banned}'::charactervarying[]) AS "states"("state"),
            LATERAL (
              SELECT
                "users".*
              FROM
                "users"
              WHERE
                (users."state" = "states"."state")
              ORDER BY
                "users"."user_type" DESC
              LIMIT 2
            ) AS users
          ORDER BY
            "users"."user_type" DESC
          LIMIT 2
        SQL
      end

      context 'when the order is an Arel node' do
        let(:order) { { user_type: :desc } }

        it 'changes the query' do
          expect(issued_query.gsub(/\s/, '')).to start_with(expected_query.gsub(/\s/, ''))
        end
      end

      context 'when the order is a Keyset order' do
        let(:order) do
          Gitlab::Pagination::Keyset::Order.build([
            Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
              attribute_name: 'user_type',
              order_expression: User.arel_table['user_type'].desc,
              nullable: :not_nullable,
              distinct: false
            )
          ])
        end

        it 'changes the query' do
          expect(issued_query.gsub(/\s/, '')).to start_with(expected_query.gsub(/\s/, ''))
        end
      end
    end

    describe 'logging' do
      subject(:load_reload) { rewriter.rewrite }

      before do
        allow(::Gitlab::AppLogger).to receive(:info)
      end

      it 'logs the call' do
        load_reload

        expect(::Gitlab::AppLogger)
          .to have_received(:info).with(message: 'Query is being rewritten by `UnnestedInFilters`', model: 'User')
      end
    end
  end
end
