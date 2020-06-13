# frozen_string_literal: true

require 'spec_helper'

describe ResourceMilestoneEvent, type: :model do
  it_behaves_like 'a resource event'
  it_behaves_like 'a resource event for issues'
  it_behaves_like 'a resource event for merge requests'

  it_behaves_like 'having unique enum values'

  describe 'associations' do
    it { is_expected.to belong_to(:milestone) }
  end

  describe 'validations' do
    context 'when issue and merge_request are both nil' do
      subject { build(described_class.name.underscore.to_sym, issue: nil, merge_request: nil) }

      it { is_expected.not_to be_valid }
    end

    context 'when issue and merge_request are both set' do
      subject { build(described_class.name.underscore.to_sym, issue: build(:issue), merge_request: build(:merge_request)) }

      it { is_expected.not_to be_valid }
    end

    context 'when issue is set' do
      subject { create(described_class.name.underscore.to_sym, issue: create(:issue), merge_request: nil) }

      it { is_expected.to be_valid }
    end

    context 'when merge_request is set' do
      subject { create(described_class.name.underscore.to_sym, issue: nil, merge_request: create(:merge_request)) }

      it { is_expected.to be_valid }
    end
  end

  describe 'states' do
    [Issue, MergeRequest].each do |klass|
      klass.available_states.each do |state|
        it "supports state #{state.first} for #{klass.name.underscore}" do
          model = create(klass.name.underscore, state: state[0])
          key = model.class.name.underscore
          event = build(described_class.name.underscore.to_sym, key => model, state: model.state)

          expect(event.state).to eq(state[0])
        end
      end
    end
  end
end
