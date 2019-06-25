# frozen_string_literal: true

require 'spec_helper'

describe Types::Tree::TypeEnum do
  it { expect(described_class.graphql_name).to eq('EntryType') }

  it 'exposes all tree entry types' do
    expect(described_class.values.keys).to include(*%w[tree blob commit])
  end
end
