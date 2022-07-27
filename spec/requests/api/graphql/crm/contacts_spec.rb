# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting CRM contacts' do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :crm_enabled) }

  let_it_be(:contact_a) do
    create(
      :contact,
      group: group,
      first_name: "ABC",
      last_name: "DEF",
      email: "ghi@test.com",
      description: "LMNO",
      state: "inactive"
    )
  end

  let_it_be(:contact_b) do
    create(
      :contact,
      group: group,
      first_name: "ABC",
      last_name: "DEF",
      email: "vwx@test.com",
      description: "YZ",
      state: "active"
    )
  end

  let_it_be(:contact_c) do
    create(
      :contact,
      group: group,
      first_name: "PQR",
      last_name: "STU",
      email: "aaa@test.com",
      description: "YZ",
      state: "active"
    )
  end

  before do
    group.add_reporter(current_user)
  end

  it_behaves_like 'sorted paginated query' do
    let(:sort_argument) { {} }
    let(:first_param) { 2 }
    let(:all_records) { [contact_a, contact_b, contact_c] }
    let(:data_path) { [:group, :contacts] }

    def pagination_query(params)
      graphql_query_for(
        :group,
        { full_path: group.full_path },
        query_graphql_field(:contacts, params, "#{page_info} nodes { id }")
      )
    end

    def pagination_results_data(nodes)
      nodes.map { |item| GlobalID::Locator.locate(item['id']) }
    end
  end
end
