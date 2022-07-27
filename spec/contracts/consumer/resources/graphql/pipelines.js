import axios from 'axios';

import { extractGraphQLQuery } from '../../helpers/graphql_query_extractor';

export async function getPipelineHeaderDataRequest(endpoint) {
  const { url } = endpoint;
  const query = await extractGraphQLQuery(
    'app/assets/javascripts/pipelines/graphql/queries/get_pipeline_header_data.query.graphql',
  );
  const graphqlQuery = {
    query,
    variables: {
      fullPath: 'gitlab-org/gitlab-qa',
      iid: 1,
    },
  };

  return axios({
    baseURL: url,
    url: '/api/graphql',
    method: 'POST',
    headers: { Accept: '*/*' },
    data: graphqlQuery,
  });
}
