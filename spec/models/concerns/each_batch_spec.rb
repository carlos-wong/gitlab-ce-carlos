# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EachBatch do
  let(:model) do
    Class.new(ActiveRecord::Base) do
      include EachBatch

      self.table_name = 'users'

      scope :never_signed_in, -> { where(sign_in_count: 0) }
    end
  end

  describe '.each_batch' do
    before do
      create_list(:user, 5, updated_at: 1.day.ago)
    end

    shared_examples 'each_batch handling' do |kwargs|
      it 'yields an ActiveRecord::Relation when a block is given' do
        model.each_batch(**kwargs) do |relation|
          expect(relation).to be_a_kind_of(ActiveRecord::Relation)
        end
      end

      it 'yields a batch index as the second argument' do
        model.each_batch(**kwargs) do |_, index|
          expect(index).to eq(1)
        end
      end

      it 'accepts a custom batch size' do
        amount = 0

        model.each_batch(**kwargs.merge({ of: 1 })) { amount += 1 }

        expect(amount).to eq(5)
      end

      it 'does not include ORDER BYs in the yielded relations' do
        model.each_batch do |relation|
          expect(relation.to_sql).not_to include('ORDER BY')
        end
      end

      it 'allows updating of the yielded relations' do
        time = Time.current

        model.each_batch do |relation|
          relation.update_all(updated_at: time)
        end

        expect(model.where(updated_at: time).count).to eq(5)
      end
    end

    it_behaves_like 'each_batch handling', {}
    it_behaves_like 'each_batch handling', { order_hint: :updated_at }

    it 'orders ascending by default' do
      ids = []

      model.each_batch(of: 1) { |rel| ids.concat(rel.ids) }

      expect(ids).to eq(ids.sort)
    end

    it 'accepts descending order' do
      ids = []

      model.each_batch(of: 1, order: :desc) { |rel| ids.concat(rel.ids) }

      expect(ids).to eq(ids.sort.reverse)
    end

    describe 'current scope' do
      let(:entry) { create(:user, sign_in_count: 1) }
      let(:ids_with_new_relation) { model.where(id: entry.id).pluck(:id) }

      it 'does not leak current scope to block being executed' do
        model.never_signed_in.each_batch(of: 5) do |relation|
          expect(ids_with_new_relation).to include(entry.id)
        end
      end
    end
  end

  describe '.distinct_each_batch' do
    let_it_be(:users) { create_list(:user, 5, sign_in_count: 0) }

    let(:params) { {} }

    subject(:values) do
      values = []

      model.distinct_each_batch(**params) { |rel| values.concat(rel.pluck(params[:column])) }
      values
    end

    context 'when iterating over a unique column' do
      context 'when using ascending order' do
        let(:expected_values) { users.pluck(:id).sort }
        let(:params) { { column: :id, of: 1, order: :asc } }

        it { is_expected.to eq(expected_values) }

        context 'when using larger batch size' do
          before do
            params[:of] = 3
          end

          it { is_expected.to eq(expected_values) }
        end

        context 'when using larger batch size than the result size' do
          before do
            params[:of] = 100
          end

          it { is_expected.to eq(expected_values) }
        end
      end

      context 'when using descending order' do
        let(:expected_values) { users.pluck(:id).sort.reverse }
        let(:params) { { column: :id, of: 1, order: :desc } }

        it { is_expected.to eq(expected_values) }

        context 'when using larger batch size' do
          before do
            params[:of] = 3
          end

          it { is_expected.to eq(expected_values) }
        end
      end
    end

    context 'when iterating over a non-unique column' do
      let(:params) { { column: :sign_in_count, of: 2, order: :asc } }

      context 'when only one value is present' do
        it { is_expected.to eq([0]) }
      end

      context 'when duplicated values present' do
        let(:expected_values) { [2, 5] }

        before do
          users[0].reload.update!(sign_in_count: 5)
          users[1].reload.update!(sign_in_count: 2)
          users[2].reload.update!(sign_in_count: 5)
          users[3].reload.update!(sign_in_count: 2)
          users[4].reload.update!(sign_in_count: 5)
        end

        it { is_expected.to eq(expected_values) }

        context 'when using descending order' do
          let(:expected_values) { [5, 2] }

          before do
            params[:order] = :desc
          end

          it { is_expected.to eq(expected_values) }
        end
      end
    end
  end
end
