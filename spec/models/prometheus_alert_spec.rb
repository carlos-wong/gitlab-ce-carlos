# frozen_string_literal: true

require 'spec_helper'

describe PrometheusAlert do
  let_it_be(:project) { build(:project) }
  let(:metric) { build(:prometheus_metric) }

  describe '.distinct_projects' do
    let(:project1) { create(:project) }
    let(:project2) { create(:project) }

    before do
      create(:prometheus_alert, project: project1)
      create(:prometheus_alert, project: project1)
      create(:prometheus_alert, project: project2)
    end

    subject { described_class.distinct_projects.count }

    it 'returns a count of all distinct projects which have an alert' do
      expect(subject).to eq(2)
    end
  end

  describe 'operators' do
    it 'contains the correct equality operator' do
      expect(described_class::OPERATORS_MAP.values).to include('==')
      expect(described_class::OPERATORS_MAP.values).not_to include('=')
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:environment) }
  end

  describe 'project validations' do
    let(:environment) { build(:environment, project: project) }
    let(:metric) { build(:prometheus_metric, project: project) }

    subject do
      build(:prometheus_alert, prometheus_metric: metric, environment: environment, project: project)
    end

    it { is_expected.to validate_presence_of(:environment) }
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:prometheus_metric) }

    context 'when environment and metric belongs same project' do
      it { is_expected.to be_valid }
    end

    context 'when environment belongs to different project' do
      let(:environment) { build(:environment) }

      it { is_expected.not_to be_valid }
    end

    context 'when metric belongs to different project' do
      let(:metric) { build(:prometheus_metric) }

      it { is_expected.not_to be_valid }
    end

    context 'when metric is common' do
      let(:metric) { build(:prometheus_metric, :common) }

      it { is_expected.to be_valid }
    end
  end

  describe '#full_query' do
    before do
      subject.operator = "gt"
      subject.threshold = 1
      subject.prometheus_metric = metric
    end

    it 'returns the concatenated query' do
      expect(subject.full_query).to eq("#{metric.query} > 1.0")
    end
  end

  describe '#to_param' do
    before do
      subject.operator = "gt"
      subject.threshold = 1
      subject.prometheus_metric = metric
    end

    it 'returns the params of the prometheus alert' do
      expect(subject.to_param).to eq(
        "alert" => metric.title,
        "expr" => "#{metric.query} > 1.0",
        "for" => "5m",
        "labels" => {
          "gitlab" => "hook",
          "gitlab_alert_id" => metric.id
        })
    end
  end
end
