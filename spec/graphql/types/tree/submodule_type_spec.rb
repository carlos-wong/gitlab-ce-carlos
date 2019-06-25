# frozen_string_literal: true

require 'spec_helper'

describe Types::Tree::SubmoduleType do
  it { expect(described_class.graphql_name).to eq('Submodule') }

  it { expect(described_class).to have_graphql_fields(:id, :name, :type, :path, :flat_path) }
end
