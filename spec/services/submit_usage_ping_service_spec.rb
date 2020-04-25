# frozen_string_literal: true

require 'spec_helper'

describe SubmitUsagePingService do
  include StubRequests

  let(:score_params) do
    {
      score: {
        leader_issues: 10.2,
        instance_issues: 3.2,
        percentage_issues: 31.37,

        leader_notes: 25.3,
        instance_notes: 23.2,

        leader_milestones: 16.2,
        instance_milestones: 5.5,

        leader_boards: 5.2,
        instance_boards: 3.2,

        leader_merge_requests: 5.2,
        instance_merge_requests: 3.2,

        leader_ci_pipelines: 25.1,
        instance_ci_pipelines: 21.3,

        leader_environments: 3.3,
        instance_environments: 2.2,

        leader_deployments: 41.3,
        instance_deployments: 15.2,

        leader_projects_prometheus_active: 0.31,
        instance_projects_prometheus_active: 0.30,

        leader_service_desk_issues: 15.8,
        instance_service_desk_issues: 15.1,

        non_existing_column: 'value'
      }
    }
  end

  let(:with_dev_ops_score_params) { { dev_ops_score: score_params[:score] } }
  let(:with_conv_index_params) { { conv_index: score_params[:score] } }
  let(:without_dev_ops_score_params) { { dev_ops_score: {} } }

  context 'when usage ping is disabled' do
    before do
      stub_application_setting(usage_ping_enabled: false)
    end

    it 'does not run' do
      expect(HTTParty).not_to receive(:post)

      result = subject.execute

      expect(result).to eq false
    end
  end

  shared_examples 'saves DevOps score data from the response' do
    it do
      expect { subject.execute }
        .to change { DevOpsScore::Metric.count }
        .by(1)

      expect(DevOpsScore::Metric.last.leader_issues).to eq 10.2
      expect(DevOpsScore::Metric.last.instance_issues).to eq 3.2
      expect(DevOpsScore::Metric.last.percentage_issues).to eq 31.37
    end
  end

  context 'when usage ping is enabled' do
    before do
      allow(ActiveRecord::Base.connection).to receive(:transaction_open?).and_return(false)
      stub_application_setting(usage_ping_enabled: true)
    end

    it 'sends a POST request' do
      response = stub_response(without_dev_ops_score_params)

      subject.execute

      expect(response).to have_been_requested
    end

    it 'refreshes usage data statistics before submitting' do
      stub_response(without_dev_ops_score_params)

      expect(Gitlab::UsageData).to receive(:to_json)
        .with(force_refresh: true)
        .and_call_original

      subject.execute
    end

    context 'when conv_index data is passed' do
      before do
        stub_response(with_conv_index_params)
      end

      it_behaves_like 'saves DevOps score data from the response'
    end

    context 'when DevOps score data is passed' do
      before do
        stub_response(with_dev_ops_score_params)
      end

      it_behaves_like 'saves DevOps score data from the response'
    end
  end

  def stub_response(body)
    stub_full_request('https://version.gitlab.com/usage_data', method: :post)
      .to_return(
        headers: { 'Content-Type' => 'application/json' },
        body: body.to_json
      )
  end
end
