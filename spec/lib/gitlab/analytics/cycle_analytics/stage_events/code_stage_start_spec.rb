# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Analytics::CycleAnalytics::StageEvents::CodeStageStart do
  let(:subject) { described_class.new({}) }
  let(:project) { create(:project) }

  it_behaves_like 'cycle analytics event'

  it 'needs connection with an issue via merge_requests_closing_issues table' do
    issue = create(:issue, project: project)
    merge_request = create(:merge_request, source_project: project)
    create(:merge_requests_closing_issues, issue: issue, merge_request: merge_request)

    other_merge_request = create(:merge_request, source_project: project, source_branch: 'a', target_branch: 'master')

    records = subject.apply_query_customization(MergeRequest.all)
    expect(records).to eq([merge_request])
    expect(records).not_to include(other_merge_request)
  end
end
