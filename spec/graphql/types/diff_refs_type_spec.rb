# frozen_string_literal: true

require 'spec_helper'

describe GitlabSchema.types['DiffRefs'] do
  it { expect(described_class.graphql_name).to eq('DiffRefs') }

  it { is_expected.to have_graphql_fields(:head_sha, :base_sha, :start_sha).only }

  it { expect(described_class.fields['headSha'].type).to be_non_null }
  it { expect(described_class.fields['baseSha'].type).not_to be_non_null }
  it { expect(described_class.fields['startSha'].type).to be_non_null }
end
