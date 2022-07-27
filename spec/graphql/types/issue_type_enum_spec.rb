# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::IssueTypeEnum do
  specify { expect(described_class.graphql_name).to eq('IssueType') }

  it 'exposes all the existing issue type values' do
    expect(described_class.values.keys).to match_array(
      %w[ISSUE INCIDENT TEST_CASE REQUIREMENT TASK]
    )
  end
end
