# frozen_string_literal: true
require 'spec_helper'

describe 'Getting Grafana Integration' do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:current_user) { project.owner }
  let_it_be(:grafana_integration) { create(:grafana_integration, project: project) }

  let(:fields) do
    <<~QUERY
      #{all_graphql_fields_for('GrafanaIntegration'.classify)}
    QUERY
  end

  let(:query) do
    graphql_query_for(
      'project',
      { 'fullPath' => project.full_path },
      query_graphql_field('grafanaIntegration', {}, fields)
    )
  end

  context 'with grafana integration data' do
    let(:integration_data) { graphql_data['project']['grafanaIntegration'] }

    context 'without project admin permissions' do
      let(:user) { create(:user) }

      before do
        project.add_developer(user)
        post_graphql(query, current_user: user)
      end

      it_behaves_like 'a working graphql query'

      it { expect(integration_data).to be nil }
    end

    context 'with project admin permissions' do
      before do
        post_graphql(query, current_user: current_user)
      end

      it_behaves_like 'a working graphql query'

      it { expect(integration_data['token']).to eql grafana_integration.masked_token }
      it { expect(integration_data['grafanaUrl']).to eql grafana_integration.grafana_url }

      it do
        expect(
          integration_data['createdAt']
        ).to eql grafana_integration.created_at.strftime('%Y-%m-%dT%H:%M:%SZ')
      end

      it do
        expect(
          integration_data['updatedAt']
        ).to eql grafana_integration.updated_at.strftime('%Y-%m-%dT%H:%M:%SZ')
      end
    end
  end
end
