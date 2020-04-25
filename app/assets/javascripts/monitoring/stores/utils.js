import { omit } from 'lodash';
import createGqClient, { fetchPolicies } from '~/lib/graphql';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';

export const gqClient = createGqClient(
  {},
  {
    fetchPolicy: fetchPolicies.NO_CACHE,
  },
);

export const uniqMetricsId = metric => `${metric.metric_id}_${metric.id}`;

/**
 * Project path has a leading slash that doesn't work well
 * with project full path resolver here
 * https://gitlab.com/gitlab-org/gitlab/blob/5cad4bd721ab91305af4505b2abc92b36a56ad6b/app/graphql/resolvers/full_path_resolver.rb#L10
 *
 * @param {String} str String with leading slash
 * @returns {String}
 */
export const removeLeadingSlash = str => (str || '').replace(/^\/+/, '');

/**
 * GraphQL environments API returns only id and name.
 * For the environments dropdown we need metrics_path.
 * This method parses the results and add neccessart attrs
 *
 * @param {Array} response Environments API result
 * @param {String} projectPath Current project path
 * @returns {Array}
 */
export const parseEnvironmentsResponse = (response = [], projectPath) =>
  (response || []).map(env => {
    const id = getIdFromGraphQLId(env.id);
    return {
      ...env,
      id,
      metrics_path: `${projectPath}/environments/${id}/metrics`,
    };
  });

/**
 * Metrics loaded from project-defined dashboards do not have a metric_id.
 * This method creates a unique ID combining metric_id and id, if either is present.
 * This is hopefully a temporary solution until BE processes metrics before passing to fE
 * @param {Object} metric - metric
 * @returns {Object} - normalized metric with a uniqueID
 */

export const normalizeMetric = (metric = {}) =>
  omit(
    {
      ...metric,
      metric_id: uniqMetricsId(metric),
      metricId: uniqMetricsId(metric),
    },
    'id',
  );

export const normalizeQueryResult = timeSeries => {
  let normalizedResult = {};

  if (timeSeries.values) {
    normalizedResult = {
      ...timeSeries,
      values: timeSeries.values.map(([timestamp, value]) => [
        new Date(timestamp * 1000).toISOString(),
        Number(value),
      ]),
    };
    // Check result for empty data
    normalizedResult.values = normalizedResult.values.filter(series => {
      const hasValue = d => !Number.isNaN(d[1]) && (d[1] !== null || d[1] !== undefined);
      return series.find(hasValue);
    });
  } else if (timeSeries.value) {
    normalizedResult = {
      ...timeSeries,
      value: [new Date(timeSeries.value[0] * 1000).toISOString(), Number(timeSeries.value[1])],
    };
  }

  return normalizedResult;
};
