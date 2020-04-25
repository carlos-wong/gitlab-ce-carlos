# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::ImportExport::GroupObjectBuilder do
  let(:group) { create(:group) }
  let(:base_attributes) do
    {
      'title'       => 'title',
      'description' => 'description',
      'group'       => group
    }
  end

  context 'labels' do
    let(:label_attributes) { base_attributes.merge('type' => 'GroupLabel') }

    it 'finds the existing group label' do
      group_label = create(:group_label, base_attributes)

      expect(described_class.build(Label, label_attributes)).to eq(group_label)
    end

    it 'creates a new label' do
      label = described_class.build(Label, label_attributes)

      expect(label.persisted?).to be true
    end

    context 'when description is an empty string' do
      let(:label_attributes) { base_attributes.merge('type' => 'GroupLabel', 'description' => '') }

      it 'finds the existing group label' do
        group_label = create(:group_label, label_attributes)

        expect(described_class.build(Label, label_attributes)).to eq(group_label)
      end
    end
  end

  context 'milestones' do
    it 'finds the existing group milestone' do
      milestone = create(:milestone, base_attributes)

      expect(described_class.build(Milestone, base_attributes)).to eq(milestone)
    end

    it 'creates a new milestone' do
      milestone = described_class.build(Milestone, base_attributes)

      expect(milestone.persisted?).to be true
    end
  end

  describe '#initialize' do
    context 'when attributes contain description as empty string' do
      let(:attributes) { base_attributes.merge('description' => '') }

      it 'converts empty string to nil' do
        builder = described_class.new(Label, attributes)

        expect(builder.send(:attributes)).to include({ 'description' => nil })
      end
    end
  end
end
