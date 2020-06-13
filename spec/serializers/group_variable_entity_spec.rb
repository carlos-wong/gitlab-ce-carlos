# frozen_string_literal: true

require 'spec_helper'

describe GroupVariableEntity do
  let(:variable) { create(:ci_group_variable) }
  let(:entity) { described_class.new(variable) }

  describe '#as_json' do
    subject { entity.as_json }

    it 'contains required fields' do
      expect(subject).to include(:id, :key, :value, :protected, :variable_type)
    end
  end
end
