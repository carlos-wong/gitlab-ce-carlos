import * as getters from '~/monitoring/stores/getters';
import mutations from '~/monitoring/stores/mutations';
import * as types from '~/monitoring/stores/mutation_types';
import { metricStates } from '~/monitoring/constants';
import {
  environmentData,
  mockedEmptyThroughputResult,
  mockedQueryResultFixture,
  mockedQueryResultFixtureStatusCode,
} from '../mock_data';
import { getJSONFixture } from '../../helpers/fixtures';

const metricsDashboardFixture = getJSONFixture(
  'metrics_dashboard/environment_metrics_dashboard.json',
);
const metricsDashboardPayload = metricsDashboardFixture.dashboard;

describe('Monitoring store Getters', () => {
  describe('getMetricStates', () => {
    let setupState;
    let state;
    let getMetricStates;

    beforeEach(() => {
      setupState = (initState = {}) => {
        state = initState;
        getMetricStates = getters.getMetricStates(state);
      };
    });

    it('has method-style access', () => {
      setupState();

      expect(getMetricStates).toEqual(expect.any(Function));
    });

    it('when dashboard has no panel groups, returns empty', () => {
      setupState({
        dashboard: {
          panelGroups: [],
        },
      });

      expect(getMetricStates()).toEqual([]);
    });

    describe('when the dashboard is set', () => {
      let groups;
      beforeEach(() => {
        setupState({
          dashboard: { panelGroups: [] },
        });
        mutations[types.RECEIVE_METRICS_DATA_SUCCESS](state, metricsDashboardPayload);
        groups = state.dashboard.panelGroups;
      });

      it('no loaded metric returns empty', () => {
        expect(getMetricStates()).toEqual([]);
      });

      it('on an empty metric with no result, returns NO_DATA', () => {
        mutations[types.RECEIVE_METRICS_DATA_SUCCESS](state, metricsDashboardPayload);
        mutations[types.RECEIVE_METRIC_RESULT_SUCCESS](state, mockedEmptyThroughputResult);

        expect(getMetricStates()).toEqual([metricStates.NO_DATA]);
      });

      it('on a metric with a result, returns OK', () => {
        mutations[types.RECEIVE_METRICS_DATA_SUCCESS](state, metricsDashboardPayload);
        mutations[types.RECEIVE_METRIC_RESULT_SUCCESS](state, mockedQueryResultFixture);

        expect(getMetricStates()).toEqual([metricStates.OK]);
      });

      it('on a metric with an error, returns an error', () => {
        mutations[types.RECEIVE_METRICS_DATA_SUCCESS](state, metricsDashboardPayload);
        mutations[types.RECEIVE_METRIC_RESULT_FAILURE](state, {
          metricId: groups[0].panels[0].metrics[0].metricId,
        });

        expect(getMetricStates()).toEqual([metricStates.UNKNOWN_ERROR]);
      });

      it('on multiple metrics with results, returns OK', () => {
        mutations[types.RECEIVE_METRICS_DATA_SUCCESS](state, metricsDashboardPayload);
        mutations[types.RECEIVE_METRIC_RESULT_SUCCESS](state, mockedQueryResultFixture);
        mutations[types.RECEIVE_METRIC_RESULT_SUCCESS](state, mockedQueryResultFixtureStatusCode);

        expect(getMetricStates()).toEqual([metricStates.OK]);

        // Filtered by groups
        expect(getMetricStates(state.dashboard.panelGroups[1].key)).toEqual([metricStates.OK]);
        expect(getMetricStates(state.dashboard.panelGroups[2].key)).toEqual([]);
      });
      it('on multiple metrics errors', () => {
        mutations[types.RECEIVE_METRICS_DATA_SUCCESS](state, metricsDashboardPayload);

        mutations[types.RECEIVE_METRIC_RESULT_FAILURE](state, {
          metricId: groups[0].panels[0].metrics[0].metricId,
        });
        mutations[types.RECEIVE_METRIC_RESULT_FAILURE](state, {
          metricId: groups[0].panels[0].metrics[0].metricId,
        });
        mutations[types.RECEIVE_METRIC_RESULT_FAILURE](state, {
          metricId: groups[1].panels[0].metrics[0].metricId,
        });

        // Entire dashboard fails
        expect(getMetricStates()).toEqual([metricStates.UNKNOWN_ERROR]);
        expect(getMetricStates(groups[0].key)).toEqual([metricStates.UNKNOWN_ERROR]);
        expect(getMetricStates(groups[1].key)).toEqual([metricStates.UNKNOWN_ERROR]);
      });

      it('on multiple metrics with errors', () => {
        mutations[types.RECEIVE_METRICS_DATA_SUCCESS](state, metricsDashboardPayload);

        // An success in 1 group
        mutations[types.RECEIVE_METRIC_RESULT_SUCCESS](state, mockedQueryResultFixture);
        // An error in 2 groups
        mutations[types.RECEIVE_METRIC_RESULT_FAILURE](state, {
          metricId: groups[1].panels[1].metrics[0].metricId,
        });
        mutations[types.RECEIVE_METRIC_RESULT_FAILURE](state, {
          metricId: groups[2].panels[0].metrics[0].metricId,
        });

        expect(getMetricStates()).toEqual([metricStates.OK, metricStates.UNKNOWN_ERROR]);
        expect(getMetricStates(groups[1].key)).toEqual([
          metricStates.OK,
          metricStates.UNKNOWN_ERROR,
        ]);
        expect(getMetricStates(groups[2].key)).toEqual([metricStates.UNKNOWN_ERROR]);
      });
    });
  });

  describe('metricsWithData', () => {
    let metricsWithData;
    let setupState;
    let state;

    beforeEach(() => {
      setupState = (initState = {}) => {
        state = initState;
        metricsWithData = getters.metricsWithData(state);
      };
    });

    afterEach(() => {
      state = null;
    });

    it('has method-style access', () => {
      setupState();

      expect(metricsWithData).toEqual(expect.any(Function));
    });

    it('when dashboard has no panel groups, returns empty', () => {
      setupState({
        dashboard: {
          panelGroups: [],
        },
      });

      expect(metricsWithData()).toEqual([]);
    });

    describe('when the dashboard is set', () => {
      beforeEach(() => {
        setupState({
          dashboard: { panelGroups: [] },
        });
      });

      it('no loaded metric returns empty', () => {
        mutations[types.RECEIVE_METRICS_DATA_SUCCESS](state, metricsDashboardPayload);

        expect(metricsWithData()).toEqual([]);
      });

      it('an empty metric, returns empty', () => {
        mutations[types.RECEIVE_METRICS_DATA_SUCCESS](state, metricsDashboardPayload);
        mutations[types.RECEIVE_METRIC_RESULT_SUCCESS](state, mockedEmptyThroughputResult);

        expect(metricsWithData()).toEqual([]);
      });

      it('a metric with results, it returns a metric', () => {
        mutations[types.RECEIVE_METRICS_DATA_SUCCESS](state, metricsDashboardPayload);
        mutations[types.RECEIVE_METRIC_RESULT_SUCCESS](state, mockedQueryResultFixture);

        expect(metricsWithData()).toEqual([mockedQueryResultFixture.metricId]);
      });

      it('multiple metrics with results, it return multiple metrics', () => {
        mutations[types.RECEIVE_METRICS_DATA_SUCCESS](state, metricsDashboardPayload);
        mutations[types.RECEIVE_METRIC_RESULT_SUCCESS](state, mockedQueryResultFixture);
        mutations[types.RECEIVE_METRIC_RESULT_SUCCESS](state, mockedQueryResultFixtureStatusCode);

        expect(metricsWithData()).toEqual([
          mockedQueryResultFixture.metricId,
          mockedQueryResultFixtureStatusCode.metricId,
        ]);
      });

      it('multiple metrics with results, it returns metrics filtered by group', () => {
        mutations[types.RECEIVE_METRICS_DATA_SUCCESS](state, metricsDashboardPayload);
        mutations[types.RECEIVE_METRIC_RESULT_SUCCESS](state, mockedQueryResultFixture);
        mutations[types.RECEIVE_METRIC_RESULT_SUCCESS](state, mockedQueryResultFixtureStatusCode);

        // First group has metrics
        expect(metricsWithData(state.dashboard.panelGroups[1].key)).toEqual([
          mockedQueryResultFixture.metricId,
          mockedQueryResultFixtureStatusCode.metricId,
        ]);

        // Second group has no metrics
        expect(metricsWithData(state.dashboard.panelGroups[2].key)).toEqual([]);
      });
    });
  });

  describe('filteredEnvironments', () => {
    let state;
    const setupState = (initState = {}) => {
      state = {
        ...state,
        ...initState,
      };
    };

    beforeAll(() => {
      setupState({
        environments: environmentData,
      });
    });

    afterAll(() => {
      state = null;
    });

    [
      {
        input: '',
        output: 17,
      },
      {
        input: '     ',
        output: 17,
      },
      {
        input: null,
        output: 17,
      },
      {
        input: 'does-not-exist',
        output: 0,
      },
      {
        input: 'noop-branch-',
        output: 15,
      },
      {
        input: 'noop-branch-9',
        output: 1,
      },
    ].forEach(({ input, output }) => {
      it(`filteredEnvironments returns ${output} items for ${input}`, () => {
        setupState({
          environmentsSearchTerm: input,
        });
        expect(getters.filteredEnvironments(state).length).toBe(output);
      });
    });
  });
});
