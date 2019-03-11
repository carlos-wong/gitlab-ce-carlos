# frozen_string_literal: true

require 'spec_helper'

describe NamespaceBasicEntity do
  set(:group) { create(:group) }
  let(:entity) do
    described_class.represent(group)
  end

  describe '#as_json' do
    subject { entity.as_json }

    it 'includes required fields' do
      expect(subject).to include :id, :full_path
    end
  end
end
