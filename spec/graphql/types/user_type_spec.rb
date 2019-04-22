# frozen_string_literal: true

require 'spec_helper'

describe GitlabSchema.types['User'] do
  it { expect(described_class.graphql_name).to eq('User') }

  it { expect(described_class).to require_graphql_authorizations(:read_user) }
end
