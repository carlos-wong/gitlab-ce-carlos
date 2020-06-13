import { slugify } from '~/lib/utils/text_utility';
import createGqClient, { fetchPolicies } from '~/lib/graphql';
import { SUPPORTED_FORMATS } from '~/lib/utils/unit_format';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';

export const gqClient = createGqClient(
  {},
  {
    fetchPolicy: fetchPolicies.NO_CACHE,
  },
);

/**
 * Metrics loaded from project-defined dashboards do not have a metric_id.
 * This method creates a unique ID combining metric_id and id, if either is present.
 * This is hopefully a temporary solution until BE processes metrics before passing to FE
 * @param {Object} metric - metric
 * @returns {Object} - normalized metric with a uniqueID
 */
// eslint-disable-next-line babel/camelcase
export const uniqMetricsId = ({ metric_id, id }) => `${metric_id}_${id}`;

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
 * Maps metrics to its view model
 *
 * This function difers from other in that is maps all
 * non-define properties as-is to the object. This is not
 * advisable as it could lead to unexpected side-effects.
 *
 * Related issue:
 * https://gitlab.com/gitlab-org/gitlab/issues/207198
 *
 * @param {Array} metrics - Array of prometheus metrics
 * @param {String} defaultLabel - Default label for metrics
 * @returns {Object}
 */
const mapToMetricsViewModel = (metrics, defaultLabel) =>
  metrics.map(({ label, id, metric_id, query_range, prometheus_endpoint_path, ...metric }) => ({
    label: label || defaultLabel,
    queryRange: query_range,
    prometheusEndpointPath: prometheus_endpoint_path,
    metricId: uniqMetricsId({ metric_id, id }),
    ...metric,
  }));

/**
 * Maps an axis view model
 *
 * Defaults to a 2 digit precision and `number` format. It only allows
 * formats in the SUPPORTED_FORMATS array.
 *
 * @param {Object} axis
 */
const mapToAxisViewModel = ({ name = '', format = SUPPORTED_FORMATS.number, precision = 2 }) => {
  return {
    name,
    format: SUPPORTED_FORMATS[format] || SUPPORTED_FORMATS.number,
    precision,
  };
};

/**
 * Maps a metrics panel to its view model
 *
 * @param {Object} panel - Metrics panel
 * @returns {Object}
 */
const mapToPanelViewModel = ({ title = '', type, y_label, y_axis = {}, metrics = [] }) => {
  // Both `y_axis.name` and `y_label` are supported for now
  // https://gitlab.com/gitlab-org/gitlab/issues/208385
  const yAxis = mapToAxisViewModel({ name: y_label, ...y_axis }); // eslint-disable-line babel/camelcase
  return {
    title,
    type,
    y_label: yAxis.name, // Changing y_label to yLabel is pending https://gitlab.com/gitlab-org/gitlab/issues/207198
    yAxis,
    metrics: mapToMetricsViewModel(metrics, yAxis.name),
  };
};

/**
 * Maps a metrics panel group to its view model
 *
 * @param {Object} panelGroup - Panel Group
 * @returns {Object}
 */
const mapToPanelGroupViewModel = ({ group = '', panels = [] }, i) => {
  return {
    key: `${slugify(group || 'default')}-${i}`,
    group,
    panels: panels.map(mapToPanelViewModel),
  };
};

/**
 * Maps a dashboard json object to its view model
 *
 * @param {Object} dashboard - Dashboard object
 * @param {String} dashboard.dashboard - Dashboard name object
 * @param {Array} dashboard.panel_groups - Panel groups array
 * @returns {Object}
 */
export const mapToDashboardViewModel = ({ dashboard = '', panel_groups = [] }) => {
  return {
    dashboard,
    panelGroups: panel_groups.map(mapToPanelGroupViewModel),
  };
};

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
