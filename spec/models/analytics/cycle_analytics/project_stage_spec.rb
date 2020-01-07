# frozen_string_literal: true

require 'spec_helper'

describe Analytics::CycleAnalytics::ProjectStage do
  describe 'associations' do
    it { is_expected.to belong_to(:project) }
  end

  it 'default stages must be valid' do
    project = create(:project)

    Gitlab::Analytics::CycleAnalytics::DefaultStages.all.each do |params|
      stage = described_class.new(params.merge(project: project))
      expect(stage).to be_valid
    end
  end

  it_behaves_like 'cycle analytics stage' do
    let(:parent) { create(:project) }
    let(:parent_name) { :project }
  end

  context 'relative positioning' do
    it_behaves_like 'a class that supports relative positioning' do
      let(:project) { create(:project) }
      let(:factory) { :cycle_analytics_project_stage }
      let(:default_params) { { project: project } }
    end
  end
end
