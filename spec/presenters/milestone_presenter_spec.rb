# frozen_string_literal: true

require 'spec_helper'

describe MilestonePresenter do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:milestone) { create(:milestone, group: group) }
  let_it_be(:presenter) { described_class.new(milestone, current_user: user) }

  before do
    group.add_developer(user)
  end

  describe '#milestone_path' do
    it 'returns correct path' do
      expect(presenter.milestone_path).to eq("/groups/#{group.full_path}/-/milestones/#{milestone.iid}")
    end
  end
end
