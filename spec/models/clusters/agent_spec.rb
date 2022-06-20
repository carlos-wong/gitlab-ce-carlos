# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Clusters::Agent do
  subject { create(:cluster_agent) }

  it { is_expected.to belong_to(:created_by_user).class_name('User').optional }
  it { is_expected.to belong_to(:project).class_name('::Project') }
  it { is_expected.to have_many(:agent_tokens).class_name('Clusters::AgentToken') }
  it { is_expected.to have_many(:last_used_agent_tokens).class_name('Clusters::AgentToken') }
  it { is_expected.to have_many(:group_authorizations).class_name('Clusters::Agents::GroupAuthorization') }
  it { is_expected.to have_many(:authorized_groups).through(:group_authorizations) }
  it { is_expected.to have_many(:project_authorizations).class_name('Clusters::Agents::ProjectAuthorization') }
  it { is_expected.to have_many(:authorized_projects).through(:project_authorizations).class_name('::Project') }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_length_of(:name).is_at_most(63) }
  it { is_expected.to validate_uniqueness_of(:name).scoped_to(:project_id) }

  describe 'scopes' do
    describe '.ordered_by_name' do
      let(:names) { %w(agent-d agent-b agent-a agent-c) }

      subject { described_class.ordered_by_name }

      before do
        names.each do |name|
          create(:cluster_agent, name: name)
        end
      end

      it { expect(subject.map(&:name)).to eq(names.sort) }
    end

    describe '.with_name' do
      let!(:matching_name) { create(:cluster_agent, name: 'matching-name') }
      let!(:other_name) { create(:cluster_agent, name: 'other-name') }

      subject { described_class.with_name(matching_name.name) }

      it { is_expected.to contain_exactly(matching_name) }
    end
  end

  describe 'validation' do
    describe 'name validation' do
      it 'rejects names that do not conform to RFC 1123', :aggregate_failures do
        %w[Agent agentA agentAagain gent- -agent agent.a agent/a agent>a].each do |name|
          agent = build(:cluster_agent, name: name)

          expect(agent).not_to be_valid
          expect(agent.errors[:name]).to eq(["can contain only lowercase letters, digits, and '-', but cannot start or end with '-'"])
        end
      end

      it 'accepts valid names', :aggregate_failures do
        %w[agent agent123 agent-123].each do |name|
          agent = build(:cluster_agent, name: name)

          expect(agent).to be_valid
        end
      end
    end
  end

  describe '#has_access_to?' do
    let(:agent) { build(:cluster_agent) }

    it 'has access to own project' do
      expect(agent.has_access_to?(agent.project)).to be_truthy
    end

    it 'does not have access to other projects' do
      expect(agent.has_access_to?(create(:project))).to be_falsey
    end
  end

  describe '#connected?' do
    let_it_be(:agent) { create(:cluster_agent) }

    let!(:token) { create(:cluster_agent_token, agent: agent, last_used_at: last_used_at) }

    subject { agent.connected? }

    context 'agent has never connected' do
      let(:last_used_at) { nil }

      it { is_expected.to be_falsey }
    end

    context 'agent has connected, but not recently' do
      let(:last_used_at) { 2.hours.ago }

      it { is_expected.to be_falsey }
    end

    context 'agent has connected recently' do
      let(:last_used_at) { 2.minutes.ago }

      it { is_expected.to be_truthy }

      context 'agent token has been revoked' do
        before do
          token.revoked!
        end

        it { is_expected.to be_falsey }
      end
    end

    context 'agent has multiple tokens' do
      let!(:inactive_token) { create(:cluster_agent_token, agent: agent, last_used_at: 2.hours.ago) }
      let(:last_used_at) { 2.minutes.ago }

      it { is_expected.to be_truthy }
    end
  end

  describe '#last_used_agent_tokens' do
    let_it_be(:agent) { create(:cluster_agent) }

    subject { agent.last_used_agent_tokens }

    context 'agent has no tokens' do
      it { is_expected.to be_empty }
    end

    context 'agent has active and inactive tokens' do
      let!(:active_token) { create(:cluster_agent_token, agent: agent, last_used_at: 1.minute.ago) }
      let!(:inactive_token) { create(:cluster_agent_token, agent: agent, last_used_at: 2.hours.ago) }

      it { is_expected.to contain_exactly(active_token, inactive_token) }
    end
  end

  describe '#activity_event_deletion_cutoff' do
    let_it_be(:agent) { create(:cluster_agent) }
    let_it_be(:event1) { create(:agent_activity_event, agent: agent, recorded_at: 1.hour.ago) }
    let_it_be(:event2) { create(:agent_activity_event, agent: agent, recorded_at: 2.hours.ago) }
    let_it_be(:event3) { create(:agent_activity_event, agent: agent, recorded_at: 3.hours.ago) }

    subject { agent.activity_event_deletion_cutoff }

    before do
      stub_const("#{described_class}::ACTIVITY_EVENT_LIMIT", 2)
    end

    it { is_expected.to be_like_time(event2.recorded_at) }
  end
end
