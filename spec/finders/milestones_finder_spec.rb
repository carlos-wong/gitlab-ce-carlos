# frozen_string_literal: true

require 'spec_helper'

describe MilestonesFinder do
  let(:now) { Time.now }
  let(:group) { create(:group) }
  let(:project_1) { create(:project, namespace: group) }
  let(:project_2) { create(:project, namespace: group) }
  let!(:milestone_1) { create(:milestone, group: group, title: 'one test', start_date: now - 1.day, due_date: now) }
  let!(:milestone_2) { create(:milestone, group: group, start_date: now + 1.day, due_date: now + 2.days) }
  let!(:milestone_3) { create(:milestone, project: project_1, state: 'active', start_date: now + 2.days, due_date: now + 3.days) }
  let!(:milestone_4) { create(:milestone, project: project_2, state: 'active', start_date: now + 4.days, due_date: now + 5.days) }

  it 'returns milestones for projects' do
    result = described_class.new(project_ids: [project_1.id, project_2.id], state: 'all').execute

    expect(result).to contain_exactly(milestone_3, milestone_4)
  end

  it 'returns milestones for groups' do
    result = described_class.new(group_ids: group.id,  state: 'all').execute

    expect(result).to contain_exactly(milestone_1, milestone_2)
  end

  context 'milestones for groups and project' do
    let(:result) do
      described_class.new(project_ids: [project_1.id, project_2.id], group_ids: group.id, state: 'all').execute
    end

    it 'returns milestones for groups and projects' do
      expect(result).to contain_exactly(milestone_1, milestone_2, milestone_3, milestone_4)
    end

    it 'orders milestones by due date' do
      milestone = create(:milestone, group: group, due_date: now - 2.days)

      expect(result.first).to eq(milestone)
      expect(result.second).to eq(milestone_1)
      expect(result.third).to eq(milestone_2)
    end
  end

  context 'with filters' do
    let(:params) do
      {
        project_ids: [project_1.id, project_2.id],
        group_ids: group.id,
        state: 'all'
      }
    end

    before do
      milestone_1.close
      milestone_3.close
    end

    it 'filters by active state' do
      params[:state] = 'active'
      result = described_class.new(params).execute

      expect(result).to contain_exactly(milestone_2, milestone_4)
    end

    it 'filters by closed state' do
      params[:state] = 'closed'
      result = described_class.new(params).execute

      expect(result).to contain_exactly(milestone_1, milestone_3)
    end

    it 'filters by title' do
      result = described_class.new(params.merge(title: 'one test')).execute

      expect(result.to_a).to contain_exactly(milestone_1)
    end

    it 'filters by search_title' do
      result = described_class.new(params.merge(search_title: 'one t')).execute

      expect(result.to_a).to contain_exactly(milestone_1)
    end

    context 'by timeframe' do
      it 'returns milestones with start_date and due_date between timeframe' do
        params.merge!(start_date: now - 1.day, end_date: now + 3.days)

        milestones = described_class.new(params).execute

        expect(milestones).to match_array([milestone_1, milestone_2, milestone_3])
      end

      it 'returns milestones which starts before the timeframe' do
        milestone = create(:milestone, project: project_2, start_date: now - 5.days)
        params.merge!(start_date: now - 3.days, end_date: now - 2.days)

        milestones = described_class.new(params).execute

        expect(milestones).to match_array([milestone])
      end

      it 'returns milestones which ends after the timeframe' do
        milestone = create(:milestone, project: project_2, due_date: now + 6.days)
        params.merge!(start_date: now + 6.days, end_date: now + 7.days)

        milestones = described_class.new(params).execute

        expect(milestones).to match_array([milestone])
      end
    end
  end

  describe '#find_by' do
    it 'finds a single milestone' do
      finder = described_class.new(project_ids: [project_1.id], state: 'all')

      expect(finder.find_by(iid: milestone_3.iid)).to eq(milestone_3)
    end
  end
end
