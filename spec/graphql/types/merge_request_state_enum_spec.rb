# frozen_string_literal: true

require 'spec_helper'

describe GitlabSchema.types['MergeRequestState'] do
  it { expect(described_class.graphql_name).to eq('MergeRequestState') }

  it_behaves_like 'issuable state'

  it 'exposes all the existing merge request states' do
    expect(described_class.values.keys).to include('merged')
  end
end
