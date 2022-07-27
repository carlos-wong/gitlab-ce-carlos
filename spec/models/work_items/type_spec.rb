# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Type do
  describe 'modules' do
    it { is_expected.to include_module(CacheMarkdownField) }
  end

  describe 'associations' do
    it { is_expected.to have_many(:work_items).with_foreign_key('work_item_type_id') }
    it { is_expected.to belong_to(:namespace) }
  end

  describe 'scopes' do
    describe 'order_by_name_asc' do
      subject { described_class.order_by_name_asc.pluck(:name) }

      before do
        # Deletes all so we have control on the entire list of names
        described_class.delete_all
        create(:work_item_type, name: 'Ztype')
        create(:work_item_type, name: 'atype')
        create(:work_item_type, name: 'gtype')
      end

      it { is_expected.to match(%w[atype gtype Ztype]) }
    end
  end

  describe '#destroy' do
    let!(:work_item) { create :issue }

    context 'when there are no work items of that type' do
      it 'deletes type but not unrelated issues' do
        type = create(:work_item_type)

        expect(WorkItems::Type.count).to eq(6)

        expect { type.destroy! }.not_to change(Issue, :count)
        expect(WorkItems::Type.count).to eq(5)
      end
    end

    it 'does not delete type when there are related issues' do
      type = create(:work_item_type, work_items: [work_item])

      expect { type.destroy! }.to raise_error(ActiveRecord::InvalidForeignKey)
      expect(Issue.count).to eq(1)
    end
  end

  describe 'validation' do
    describe 'name uniqueness' do
      subject { create(:work_item_type) }

      it { is_expected.to validate_uniqueness_of(:name).case_insensitive.scoped_to([:namespace_id]) }
    end

    it { is_expected.not_to allow_value('s' * 256).for(:icon_name) }
  end

  describe '.available_widgets' do
    subject { described_class.available_widgets }

    it 'returns list of all possible widgets' do
      is_expected.to match_array([::WorkItems::Widgets::Description,
                                  ::WorkItems::Widgets::Hierarchy,
                                  ::WorkItems::Widgets::Assignees,
                                  ::WorkItems::Widgets::Weight])
    end
  end

  describe '#default?' do
    subject { build(:work_item_type, namespace: namespace).default? }

    context 'when namespace is nil' do
      let(:namespace) { nil }

      it { is_expected.to be_truthy }
    end

    context 'when namespace is present' do
      let(:namespace) { build(:namespace) }

      it { is_expected.to be_falsey }
    end
  end

  describe '#name' do
    it 'strips name' do
      work_item_type = described_class.new(name: '   label😸   ')
      work_item_type.valid?

      expect(work_item_type.name).to eq('label😸')
    end
  end
end
