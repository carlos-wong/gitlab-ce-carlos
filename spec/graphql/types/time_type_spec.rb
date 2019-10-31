# frozen_string_literal: true

require 'spec_helper'

describe GitlabSchema.types['Time'] do
  let(:iso) { "2018-06-04T15:23:50+02:00" }
  let(:time) { Time.parse(iso) }

  it { expect(described_class.graphql_name).to eq('Time') }

  it 'coerces Time object into ISO 8601' do
    expect(described_class.coerce_isolated_result(time)).to eq(iso)
  end

  it 'coerces an ISO-time into Time object' do
    expect(described_class.coerce_isolated_input(iso)).to eq(time)
  end
end
