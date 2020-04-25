# frozen_string_literal: true

require 'spec_helper'

describe Types::BlobViewers::TypeEnum do
  it { expect(described_class.graphql_name).to eq('BlobViewersType') }

  it 'exposes all tree entry types' do
    expect(described_class.values.keys).to include(*%w[rich simple auxiliary])
  end
end
