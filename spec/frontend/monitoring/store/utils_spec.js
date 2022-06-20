import { SUPPORTED_FORMATS } from '~/lib/utils/unit_format';
import * as urlUtils from '~/lib/utils/url_utility';
import { NOT_IN_DB_PREFIX } from '~/monitoring/constants';
import {
  uniqMetricsId,
  parseEnvironmentsResponse,
  parseAnnotationsResponse,
  removeLeadingSlash,
  mapToDashboardViewModel,
  normalizeQueryResponseData,
  convertToGrafanaTimeRange,
  addDashboardMetaDataToLink,
  normalizeCustomDashboardPath,
} from '~/monitoring/stores/utils';
import { annotationsData } from '../mock_data';

const projectPath = 'gitlab-org/gitlab-test';

describe('mapToDashboardViewModel', () => {
  it('maps an empty dashboard', () => {
    expect(mapToDashboardViewModel({})).toEqual({
      dashboard: '',
      panelGroups: [],
      links: [],
      variables: [],
    });
  });

  it('maps a simple dashboard', () => {
    const response = {
      dashboard: 'Dashboard Name',
      panel_groups: [
        {
          group: 'Group 1',
          panels: [
            {
              id: 'ID_ABC',
              title: 'Title A',
              xLabel: '',
              xAxis: {
                name: '',
              },
              type: 'chart-type',
              y_label: 'Y Label A',
              metrics: [],
            },
          ],
        },
      ],
    };

    expect(mapToDashboardViewModel(response)).toEqual({
      dashboard: 'Dashboard Name',
      links: [],
      variables: [],
      panelGroups: [
        {
          group: 'Group 1',
          key: 'group-1-0',
          panels: [
            {
              id: 'ID_ABC',
              title: 'Title A',
              type: 'chart-type',
              xLabel: '',
              xAxis: {
                name: '',
              },
              y_label: 'Y Label A',
              yAxis: {
                name: 'Y Label A',
                format: 'engineering',
                precision: 2,
              },
              links: [],
              metrics: [],
            },
          ],
        },
      ],
    });
  });

  describe('panel groups mapping', () => {
    it('key', () => {
      const response = {
        dashboard: 'Dashboard Name',
        links: [],
        variables: {},
        panel_groups: [
          {
            group: 'Group A',
          },
          {
            group: 'Group B',
          },
          {
            group: '',
            unsupported_property: 'This should be removed',
          },
        ],
      };

      expect(mapToDashboardViewModel(response).panelGroups).toEqual([
        {
          group: 'Group A',
          key: 'group-a-0',
          panels: [],
        },
        {
          group: 'Group B',
          key: 'group-b-1',
          panels: [],
        },
        {
          group: '',
          key: 'default-2',
          panels: [],
        },
      ]);
    });
  });

  describe('panel mapping', () => {
    const panelTitle = 'Panel Title';
    const yAxisName = 'Y Axis Name';

    let dashboard;

    const setupWithPanel = (panel) => {
      dashboard = {
        panel_groups: [
          {
            panels: [panel],
          },
        ],
      };
    };

    const getMappedPanel = () => mapToDashboardViewModel(dashboard).panelGroups[0].panels[0];

    it('panel with x_label', () => {
      setupWithPanel({
        id: 'ID_123',
        title: panelTitle,
        x_label: 'x label',
      });

      expect(getMappedPanel()).toEqual({
        id: 'ID_123',
        title: panelTitle,
        xLabel: 'x label',
        xAxis: {
          name: 'x label',
        },
        y_label: '',
        yAxis: {
          name: '',
          format: SUPPORTED_FORMATS.engineering,
          precision: 2,
        },
        links: [],
        metrics: [],
      });
    });

    it('group y_axis defaults', () => {
      setupWithPanel({
        id: 'ID_456',
        title: panelTitle,
      });

      expect(getMappedPanel()).toEqual({
        id: 'ID_456',
        title: panelTitle,
        xLabel: '',
        y_label: '',
        xAxis: {
          name: '',
        },
        yAxis: {
          name: '',
          format: SUPPORTED_FORMATS.engineering,
          precision: 2,
        },
        links: [],
        metrics: [],
      });
    });

    it('panel with y_axis.name', () => {
      setupWithPanel({
        y_axis: {
          name: yAxisName,
        },
      });

      expect(getMappedPanel().y_label).toBe(yAxisName);
      expect(getMappedPanel().yAxis.name).toBe(yAxisName);
    });

    it('panel with y_axis.name and y_label, displays y_axis.name', () => {
      setupWithPanel({
        y_label: 'Ignored Y Label',
        y_axis: {
          name: yAxisName,
        },
      });

      expect(getMappedPanel().y_label).toBe(yAxisName);
      expect(getMappedPanel().yAxis.name).toBe(yAxisName);
    });

    it('group y_label', () => {
      setupWithPanel({
        y_label: yAxisName,
      });

      expect(getMappedPanel().y_label).toBe(yAxisName);
      expect(getMappedPanel().yAxis.name).toBe(yAxisName);
    });

    it('group y_axis format and precision', () => {
      setupWithPanel({
        title: panelTitle,
        y_axis: {
          precision: 0,
          format: SUPPORTED_FORMATS.bytes,
        },
      });

      expect(getMappedPanel().yAxis.format).toBe(SUPPORTED_FORMATS.bytes);
      expect(getMappedPanel().yAxis.precision).toBe(0);
    });

    it('group y_axis unsupported format defaults to number', () => {
      setupWithPanel({
        title: panelTitle,
        y_axis: {
          format: 'invalid_format',
        },
      });

      expect(getMappedPanel().yAxis.format).toBe(SUPPORTED_FORMATS.engineering);
    });

    // This property allows single_stat panels to render percentile values
    it('group maxValue', () => {
      setupWithPanel({
        max_value: 100,
      });

      expect(getMappedPanel().maxValue).toBe(100);
    });

    describe('panel with links', () => {
      const title = 'Example';
      const url = 'https://example.com';

      it('maps an empty link collection', () => {
        setupWithPanel({
          links: undefined,
        });

        expect(getMappedPanel().links).toEqual([]);
      });

      it('maps a link', () => {
        setupWithPanel({ links: [{ title, url }] });

        expect(getMappedPanel().links).toEqual([{ title, url }]);
      });

      it('maps a link without a title', () => {
        setupWithPanel({
          links: [{ url }],
        });

        expect(getMappedPanel().links).toEqual([{ title: url, url }]);
      });

      it('maps a link without a url', () => {
        setupWithPanel({
          links: [{ title }],
        });

        expect(getMappedPanel().links).toEqual([{ title, url: '#' }]);
      });

      it('maps a link without a url or title', () => {
        setupWithPanel({
          links: [{}],
        });

        expect(getMappedPanel().links).toEqual([{ title: 'null', url: '#' }]);
      });

      it('maps a link with an unsafe url safely', () => {
        // eslint-disable-next-line no-script-url
        const unsafeUrl = 'javascript:alert("XSS")';

        setupWithPanel({
          links: [
            {
              title,
              url: unsafeUrl,
            },
          ],
        });

        expect(getMappedPanel().links).toEqual([{ title, url: '#' }]);
      });

      it('maps multple links', () => {
        setupWithPanel({
          links: [{ title, url }, { url }, { title }],
        });

        expect(getMappedPanel().links).toEqual([
          { title, url },
          { title: url, url },
          { title, url: '#' },
        ]);
      });
    });
  });

  describe('metrics mapping', () => {
    const defaultLabel = 'Panel Label';
    const dashboardWithMetric = (metric, label = defaultLabel) => ({
      panel_groups: [
        {
          panels: [
            {
              y_label: label,
              metrics: [metric],
            },
          ],
        },
      ],
    });

    const getMappedMetric = (dashboard) => {
      return mapToDashboardViewModel(dashboard).panelGroups[0].panels[0].metrics[0];
    };

    it('creates a metric', () => {
      const dashboard = dashboardWithMetric({ label: 'Panel Label' });

      expect(getMappedMetric(dashboard)).toEqual({
        label: expect.any(String),
        metricId: expect.any(String),
        loading: false,
        result: null,
        state: null,
      });
    });

    it('creates a metric with a correct id', () => {
      const dashboard = dashboardWithMetric({
        id: 'http_responses',
        metric_id: 1,
      });

      expect(getMappedMetric(dashboard).metricId).toEqual('1_http_responses');
    });

    it('creates a metric without a default label', () => {
      const dashboard = dashboardWithMetric({});

      expect(getMappedMetric(dashboard)).toMatchObject({
        label: undefined,
      });
    });

    it('creates a metric with an endpoint and query', () => {
      const dashboard = dashboardWithMetric({
        prometheus_endpoint_path: 'http://test',
        query_range: 'http_responses',
      });

      expect(getMappedMetric(dashboard)).toMatchObject({
        prometheusEndpointPath: 'http://test',
        queryRange: 'http_responses',
      });
    });

    it('creates a metric with an ad-hoc property', () => {
      // This behavior is deprecated and should be removed
      // https://gitlab.com/gitlab-org/gitlab/issues/207198

      const dashboard = dashboardWithMetric({
        x_label: 'Another label',
        unkown_option: 'unkown_data',
      });

      expect(getMappedMetric(dashboard)).toMatchObject({
        x_label: 'Another label',
        unkown_option: 'unkown_data',
      });
    });
  });

  describe('templating variables mapping', () => {
    beforeEach(() => {
      jest.spyOn(urlUtils, 'queryToObject');
    });

    afterEach(() => {
      urlUtils.queryToObject.mockRestore();
    });

    it('sets variables as-is from yml file if URL has no variables', () => {
      const response = {
        dashboard: 'Dashboard Name',
        links: [],
        templating: {
          variables: {
            pod: 'kubernetes',
            pod_2: 'kubernetes-2',
          },
        },
      };

      urlUtils.queryToObject.mockReturnValueOnce();

      expect(mapToDashboardViewModel(response).variables).toEqual([
        {
          name: 'pod',
          label: 'pod',
          type: 'text',
          value: 'kubernetes',
        },
        {
          name: 'pod_2',
          label: 'pod_2',
          type: 'text',
          value: 'kubernetes-2',
        },
      ]);
    });

    it('sets variables as-is from yml file if URL has no matching variables', () => {
      const response = {
        dashboard: 'Dashboard Name',
        links: [],
        templating: {
          variables: {
            pod: 'kubernetes',
            pod_2: 'kubernetes-2',
          },
        },
      };

      urlUtils.queryToObject.mockReturnValueOnce({
        'var-environment': 'POD',
      });

      expect(mapToDashboardViewModel(response).variables).toEqual([
        {
          label: 'pod',
          name: 'pod',
          type: 'text',
          value: 'kubernetes',
        },
        {
          label: 'pod_2',
          name: 'pod_2',
          type: 'text',
          value: 'kubernetes-2',
        },
      ]);
    });

    it('merges variables from URL with the ones from yml file', () => {
      const response = {
        dashboard: 'Dashboard Name',
        links: [],
        templating: {
          variables: {
            pod: 'kubernetes',
            pod_2: 'kubernetes-2',
          },
        },
      };

      urlUtils.queryToObject.mockReturnValueOnce({
        'var-environment': 'POD',
        'var-pod': 'POD1',
        'var-pod_2': 'POD2',
      });

      expect(mapToDashboardViewModel(response).variables).toEqual([
        {
          label: 'pod',
          name: 'pod',
          type: 'text',
          value: 'POD1',
        },
        {
          label: 'pod_2',
          name: 'pod_2',
          type: 'text',
          value: 'POD2',
        },
      ]);
    });
  });
});

describe('uniqMetricsId', () => {
  [
    { input: { id: 1 }, expected: `${NOT_IN_DB_PREFIX}_1` },
    { input: { metric_id: 2 }, expected: '2_undefined' },
    { input: { metric_id: 2, id: 21 }, expected: '2_21' },
    { input: { metric_id: 22, id: 1 }, expected: '22_1' },
    { input: { metric_id: 'aaa', id: '_a' }, expected: 'aaa__a' },
  ].forEach(({ input, expected }) => {
    it(`creates unique metric ID with ${JSON.stringify(input)}`, () => {
      expect(uniqMetricsId(input)).toEqual(expected);
    });
  });
});

describe('parseEnvironmentsResponse', () => {
  [
    {
      input: null,
      output: [],
    },
    {
      input: undefined,
      output: [],
    },
    {
      input: [],
      output: [],
    },
    {
      input: [
        {
          id: '1',
          name: 'env-1',
        },
      ],
      output: [
        {
          id: 1,
          name: 'env-1',
          metrics_path: `${projectPath}/-/metrics?environment=1`,
        },
      ],
    },
    {
      input: [
        {
          id: 'gid://gitlab/Environment/12',
          name: 'env-12',
        },
      ],
      output: [
        {
          id: 12,
          name: 'env-12',
          metrics_path: `${projectPath}/-/metrics?environment=12`,
        },
      ],
    },
  ].forEach(({ input, output }) => {
    it(`parseEnvironmentsResponse returns ${JSON.stringify(output)} with input ${JSON.stringify(
      input,
    )}`, () => {
      expect(parseEnvironmentsResponse(input, projectPath)).toEqual(output);
    });
  });
});

describe('parseAnnotationsResponse', () => {
  const parsedAnnotationResponse = [
    {
      description: 'This is a test annotation',
      endingAt: null,
      id: 'gid://gitlab/Metrics::Dashboard::Annotation/1',
      panelId: null,
      startingAt: new Date('2020-04-12T12:51:53.000Z'),
    },
  ];
  it.each`
    case                                               | input                   | expected
    ${'Returns empty array for null input'}            | ${null}                 | ${[]}
    ${'Returns empty array for undefined input'}       | ${undefined}            | ${[]}
    ${'Returns empty array for empty input'}           | ${[]}                   | ${[]}
    ${'Returns parsed responses for annotations data'} | ${[annotationsData[0]]} | ${parsedAnnotationResponse}
  `('$case', ({ input, expected }) => {
    expect(parseAnnotationsResponse(input)).toEqual(expected);
  });
});

describe('removeLeadingSlash', () => {
  [
    { input: null, output: '' },
    { input: '', output: '' },
    { input: 'gitlab-org', output: 'gitlab-org' },
    { input: 'gitlab-org/gitlab', output: 'gitlab-org/gitlab' },
    { input: '/gitlab-org/gitlab', output: 'gitlab-org/gitlab' },
    { input: '////gitlab-org/gitlab', output: 'gitlab-org/gitlab' },
  ].forEach(({ input, output }) => {
    it(`removeLeadingSlash returns ${output} with input ${input}`, () => {
      expect(removeLeadingSlash(input)).toEqual(output);
    });
  });
});

describe('user-defined links utils', () => {
  const mockRelativeTimeRange = {
    metricsDashboard: {
      duration: {
        seconds: 86400,
      },
    },
    grafana: {
      from: 'now-86400s',
      to: 'now',
    },
  };
  const mockAbsoluteTimeRange = {
    metricsDashboard: {
      start: '2020-06-08T16:13:01.995Z',
      end: '2020-06-08T21:12:32.243Z',
    },
    grafana: {
      from: 1591632781995,
      to: 1591650752243,
    },
  };
  describe('convertToGrafanaTimeRange', () => {
    it('converts relative timezone to grafana timezone', () => {
      expect(convertToGrafanaTimeRange(mockRelativeTimeRange.metricsDashboard)).toEqual(
        mockRelativeTimeRange.grafana,
      );
    });

    it('converts absolute timezone to grafana timezone', () => {
      expect(convertToGrafanaTimeRange(mockAbsoluteTimeRange.metricsDashboard)).toEqual(
        mockAbsoluteTimeRange.grafana,
      );
    });
  });

  describe('addDashboardMetaDataToLink', () => {
    const link = { title: 'title', url: 'https://gitlab.com' };
    const grafanaLink = { ...link, type: 'grafana' };

    it('adds relative time range to link w/o type for metrics dashboards', () => {
      const adder = addDashboardMetaDataToLink({
        timeRange: mockRelativeTimeRange.metricsDashboard,
      });
      expect(adder(link)).toMatchObject({
        title: 'title',
        url: 'https://gitlab.com?duration_seconds=86400',
      });
    });

    it('adds relative time range to Grafana type links', () => {
      const adder = addDashboardMetaDataToLink({
        timeRange: mockRelativeTimeRange.metricsDashboard,
      });
      expect(adder(grafanaLink)).toMatchObject({
        title: 'title',
        url: 'https://gitlab.com?from=now-86400s&to=now',
      });
    });

    it('adds absolute time range to link w/o type for metrics dashboard', () => {
      const adder = addDashboardMetaDataToLink({
        timeRange: mockAbsoluteTimeRange.metricsDashboard,
      });
      expect(adder(link)).toMatchObject({
        title: 'title',
        url:
          'https://gitlab.com?start=2020-06-08T16%3A13%3A01.995Z&end=2020-06-08T21%3A12%3A32.243Z',
      });
    });

    it('adds absolute time range to Grafana type links', () => {
      const adder = addDashboardMetaDataToLink({
        timeRange: mockAbsoluteTimeRange.metricsDashboard,
      });
      expect(adder(grafanaLink)).toMatchObject({
        title: 'title',
        url: 'https://gitlab.com?from=1591632781995&to=1591650752243',
      });
    });
  });
});

describe('normalizeQueryResponseData', () => {
  // Data examples from
  // https://prometheus.io/docs/prometheus/latest/querying/api/#expression-queries

  it('processes a string result', () => {
    const mockScalar = {
      resultType: 'string',
      result: [1435781451.781, '1'],
    };

    expect(normalizeQueryResponseData(mockScalar)).toEqual([
      {
        metric: {},
        value: ['2015-07-01T20:10:51.781Z', '1'],
        values: [['2015-07-01T20:10:51.781Z', '1']],
      },
    ]);
  });

  it('processes a scalar result', () => {
    const mockScalar = {
      resultType: 'scalar',
      result: [1435781451.781, '1'],
    };

    expect(normalizeQueryResponseData(mockScalar)).toEqual([
      {
        metric: {},
        value: ['2015-07-01T20:10:51.781Z', 1],
        values: [['2015-07-01T20:10:51.781Z', 1]],
      },
    ]);
  });

  it('processes a vector result', () => {
    const mockVector = {
      resultType: 'vector',
      result: [
        {
          metric: {
            __name__: 'up',
            job: 'prometheus',
            instance: 'localhost:9090',
          },
          value: [1435781451.781, '1'],
        },
        {
          metric: {
            __name__: 'up',
            job: 'node',
            instance: 'localhost:9100',
          },
          value: [1435781451.781, '0'],
        },
      ],
    };

    expect(normalizeQueryResponseData(mockVector)).toEqual([
      {
        metric: { __name__: 'up', job: 'prometheus', instance: 'localhost:9090' },
        value: ['2015-07-01T20:10:51.781Z', 1],
        values: [['2015-07-01T20:10:51.781Z', 1]],
      },
      {
        metric: { __name__: 'up', job: 'node', instance: 'localhost:9100' },
        value: ['2015-07-01T20:10:51.781Z', 0],
        values: [['2015-07-01T20:10:51.781Z', 0]],
      },
    ]);
  });

  it('processes a matrix result', () => {
    const mockMatrix = {
      resultType: 'matrix',
      result: [
        {
          metric: {
            __name__: 'up',
            job: 'prometheus',
            instance: 'localhost:9090',
          },
          values: [
            [1435781430.781, '1'],
            [1435781445.781, '2'],
            [1435781460.781, '3'],
          ],
        },
        {
          metric: {
            __name__: 'up',
            job: 'node',
            instance: 'localhost:9091',
          },
          values: [
            [1435781430.781, '4'],
            [1435781445.781, '5'],
            [1435781460.781, '6'],
          ],
        },
      ],
    };

    expect(normalizeQueryResponseData(mockMatrix)).toEqual([
      {
        metric: { __name__: 'up', instance: 'localhost:9090', job: 'prometheus' },
        value: ['2015-07-01T20:11:00.781Z', 3],
        values: [
          ['2015-07-01T20:10:30.781Z', 1],
          ['2015-07-01T20:10:45.781Z', 2],
          ['2015-07-01T20:11:00.781Z', 3],
        ],
      },
      {
        metric: { __name__: 'up', instance: 'localhost:9091', job: 'node' },
        value: ['2015-07-01T20:11:00.781Z', 6],
        values: [
          ['2015-07-01T20:10:30.781Z', 4],
          ['2015-07-01T20:10:45.781Z', 5],
          ['2015-07-01T20:11:00.781Z', 6],
        ],
      },
    ]);
  });

  it('processes a scalar result with a NaN result', () => {
    // Queries may return "NaN" string values.
    // e.g. when Prometheus cannot find a metric the query
    // `scalar(does_not_exist)` will return a "NaN" value.

    const mockScalar = {
      resultType: 'scalar',
      result: [1435781451.781, 'NaN'],
    };

    expect(normalizeQueryResponseData(mockScalar)).toEqual([
      {
        metric: {},
        value: ['2015-07-01T20:10:51.781Z', NaN],
        values: [['2015-07-01T20:10:51.781Z', NaN]],
      },
    ]);
  });

  it('processes a matrix result with a "NaN" value', () => {
    // Queries may return "NaN" string values.
    const mockMatrix = {
      resultType: 'matrix',
      result: [
        {
          metric: {
            __name__: 'up',
            job: 'prometheus',
            instance: 'localhost:9090',
          },
          values: [
            [1435781430.781, '1'],
            [1435781460.781, 'NaN'],
          ],
        },
      ],
    };

    expect(normalizeQueryResponseData(mockMatrix)).toEqual([
      {
        metric: { __name__: 'up', instance: 'localhost:9090', job: 'prometheus' },
        value: ['2015-07-01T20:11:00.781Z', NaN],
        values: [
          ['2015-07-01T20:10:30.781Z', 1],
          ['2015-07-01T20:11:00.781Z', NaN],
        ],
      },
    ]);
  });
});

describe('normalizeCustomDashboardPath', () => {
  it.each`
    input                                                               | expected
    ${[undefined]}                                                      | ${''}
    ${[null]}                                                           | ${''}
    ${[]}                                                               | ${''}
    ${['links.yml']}                                                    | ${'links.yml'}
    ${['links.yml', '.gitlab/dashboards']}                              | ${'.gitlab/dashboards/links.yml'}
    ${['config/prometheus/common_metrics.yml']}                         | ${'config/prometheus/common_metrics.yml'}
    ${['config/prometheus/common_metrics.yml', '.gitlab/dashboards']}   | ${'config/prometheus/common_metrics.yml'}
    ${['dir1/links.yml', '.gitlab/dashboards']}                         | ${'.gitlab/dashboards/dir1/links.yml'}
    ${['dir1/dir2/links.yml', '.gitlab/dashboards']}                    | ${'.gitlab/dashboards/dir1/dir2/links.yml'}
    ${['.gitlab/dashboards/links.yml']}                                 | ${'.gitlab/dashboards/links.yml'}
    ${['.gitlab/dashboards/links.yml', '.gitlab/dashboards']}           | ${'.gitlab/dashboards/links.yml'}
    ${['.gitlab/dashboards/dir1/links.yml', '.gitlab/dashboards']}      | ${'.gitlab/dashboards/dir1/links.yml'}
    ${['.gitlab/dashboards/dir1/dir2/links.yml', '.gitlab/dashboards']} | ${'.gitlab/dashboards/dir1/dir2/links.yml'}
    ${['config/prometheus/pod_metrics.yml', '.gitlab/dashboards']}      | ${'config/prometheus/pod_metrics.yml'}
    ${['config/prometheus/pod_metrics.yml']}                            | ${'config/prometheus/pod_metrics.yml'}
  `(`normalizeCustomDashboardPath returns $expected for $input`, ({ input, expected }) => {
    expect(normalizeCustomDashboardPath(...input)).toEqual(expected);
  });
});
