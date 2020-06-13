# frozen_string_literal: true

require 'spec_helper'

describe BulkInsertableAssociations do
  class BulkFoo < ApplicationRecord
    include BulkInsertSafe

    validates :name, presence: true
  end

  class BulkBar < ApplicationRecord
    include BulkInsertSafe
  end

  SimpleBar = Class.new(ApplicationRecord)

  class BulkParent < ApplicationRecord
    include BulkInsertableAssociations

    has_many :bulk_foos
    has_many :bulk_hunks, class_name: 'BulkFoo'
    has_many :bulk_bars
    has_many :simple_bars # not `BulkInsertSafe`
    has_one :bulk_foo # not supported
  end

  before(:all) do
    ActiveRecord::Schema.define do
      create_table :bulk_parents, force: true do |t|
        t.string :name, null: true
      end

      create_table :bulk_foos, force: true do |t|
        t.string :name, null: true
        t.belongs_to :bulk_parent, null: false
      end

      create_table :bulk_bars, force: true do |t|
        t.string :name, null: true
        t.belongs_to :bulk_parent, null: false
      end

      create_table :simple_bars, force: true do |t|
        t.string :name, null: true
        t.belongs_to :bulk_parent, null: false
      end
    end
  end

  after(:all) do
    ActiveRecord::Schema.define do
      drop_table :bulk_foos, force: true
      drop_table :bulk_bars, force: true
      drop_table :simple_bars, force: true
      drop_table :bulk_parents, force: true
    end
  end

  context 'saving bulk insertable associations' do
    let(:parent) { BulkParent.new(name: 'parent') }

    context 'when items already have IDs' do
      it 'stores nothing and raises an error' do
        build_items(parent: parent) { |n, item| item.id = n }

        expect { save_with_bulk_inserts(parent) }.to raise_error(BulkInsertSafe::PrimaryKeySetError)
        expect(BulkFoo.count).to eq(0)
      end
    end

    context 'when items have no IDs set' do
      it 'stores them all and updates items with IDs' do
        items = build_items(parent: parent)

        expect(BulkFoo).to receive(:bulk_insert!).once.and_call_original
        expect { save_with_bulk_inserts(parent) }.to change { BulkFoo.count }.from(0).to(items.size)
        expect(parent.bulk_foos.pluck(:id)).to all(be_a Integer)
      end
    end

    context 'when items are empty' do
      it 'does nothing' do
        expect(parent.bulk_foos).to be_empty

        expect { save_with_bulk_inserts(parent) }.not_to change { BulkFoo.count }
      end
    end

    context 'when relation name does not match class name' do
      it 'stores them all' do
        items = build_items(parent: parent, relation: :bulk_hunks)

        expect(BulkFoo).to receive(:bulk_insert!).once.and_call_original

        expect { save_with_bulk_inserts(parent) }.to(
          change { BulkFoo.count }.from(0).to(items.size)
        )
      end
    end

    context 'with multiple threads' do
      it 'isolates bulk insert behavior between threads' do
        total_item_count = 10
        parent1 = BulkParent.new(name: 'parent1')
        parent2 = BulkParent.new(name: 'parent2')
        build_items(parent: parent1, count: total_item_count / 2)
        build_items(parent: parent2, count: total_item_count / 2)

        expect(BulkFoo).to receive(:bulk_insert!).once.and_call_original
        [
          Thread.new do
            save_with_bulk_inserts(parent1)
          end,
          Thread.new do
            parent2.save!
          end
        ].map(&:join)

        expect(BulkFoo.count).to eq(total_item_count)
      end
    end

    context 'with multiple associations' do
      it 'isolates writes between associations' do
        items1 = build_items(parent: parent, relation: :bulk_foos)
        items2 = build_items(parent: parent, relation: :bulk_bars)

        expect(BulkFoo).to receive(:bulk_insert!).once.and_call_original
        expect(BulkBar).to receive(:bulk_insert!).once.and_call_original

        expect { save_with_bulk_inserts(parent) }.to(
          change { BulkFoo.count }.from(0).to(items1.size)
        .and(
          change { BulkBar.count }.from(0).to(items2.size)
        ))
      end
    end

    context 'passing bulk insert arguments' do
      it 'disables validations on target association' do
        items = build_items(parent: parent)

        expect(BulkFoo).to receive(:bulk_insert!).with(items, validate: false).and_return true

        save_with_bulk_inserts(parent)
      end
    end

    it 'can disable bulk-inserts within a bulk-insert block' do
      parent1 = BulkParent.new(name: 'parent1')
      parent2 = BulkParent.new(name: 'parent2')
      _items1 = build_items(parent: parent1)
      items2 = build_items(parent: parent2)

      expect(BulkFoo).to receive(:bulk_insert!).once.with(items2, validate: false)

      BulkInsertableAssociations.with_bulk_insert(enabled: true) do
        BulkInsertableAssociations.with_bulk_insert(enabled: false) do
          parent1.save!
        end

        parent2.save!
      end
    end

    context 'when association is not bulk-insert safe' do
      it 'saves it normally' do
        parent.simple_bars.build

        expect(SimpleBar).not_to receive(:bulk_insert!)
        expect { save_with_bulk_inserts(parent) }.to change { SimpleBar.count }.from(0).to(1)
      end
    end

    context 'when association is not has_many' do
      it 'saves it normally' do
        parent.bulk_foo = BulkFoo.new(name: 'item')

        expect(BulkFoo).not_to receive(:bulk_insert!)
        expect { save_with_bulk_inserts(parent) }.to change { BulkFoo.count }.from(0).to(1)
      end
    end

    context 'when an item is not valid' do
      describe '.save' do
        it 'invalidates the parent and returns false' do
          build_invalid_items(parent: parent)

          expect(save_with_bulk_inserts(parent, bangify: false)).to be false
          expect(parent.errors[:bulk_foos].size).to eq(1)

          expect(BulkFoo.count).to eq(0)
          expect(BulkParent.count).to eq(0)
        end
      end

      describe '.save!' do
        it 'invalidates the parent and raises error' do
          build_invalid_items(parent: parent)

          expect { save_with_bulk_inserts(parent) }.to raise_error(ActiveRecord::RecordInvalid)
          expect(parent.errors[:bulk_foos].size).to eq(1)

          expect(BulkFoo.count).to eq(0)
          expect(BulkParent.count).to eq(0)
        end
      end
    end
  end

  private

  def save_with_bulk_inserts(entity, bangify: true)
    BulkInsertableAssociations.with_bulk_insert { bangify ? entity.save! : entity.save }
  end

  def build_items(parent:, relation: :bulk_foos, count: 10)
    count.times do |n|
      item = parent.send(relation).build(name: "item_#{n}", bulk_parent_id: parent.id)
      yield(n, item) if block_given?
    end
    parent.send(relation)
  end

  def build_invalid_items(parent:)
    build_items(parent: parent).tap do |items|
      invalid_item = items.first
      invalid_item.name = nil
      expect(invalid_item).not_to be_valid
    end
  end
end
