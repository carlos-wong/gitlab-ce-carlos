import * as types from './mutation_types';
import { convertToFixedRange } from '~/lib/utils/datetime_range';

const mapLine = ({ timestamp, message }) => ({
  timestamp,
  message,
});

export default {
  // Search Data
  [types.SET_SEARCH](state, searchQuery) {
    state.search = searchQuery;
  },

  // Time Range Data
  [types.SET_TIME_RANGE](state, timeRange) {
    state.timeRange.selected = timeRange;
    state.timeRange.current = convertToFixedRange(timeRange);
  },

  // Environments Data
  [types.SET_PROJECT_ENVIRONMENT](state, environmentName) {
    state.environments.current = environmentName;
  },
  [types.REQUEST_ENVIRONMENTS_DATA](state) {
    state.environments.options = [];
    state.environments.isLoading = true;
  },
  [types.RECEIVE_ENVIRONMENTS_DATA_SUCCESS](state, environmentOptions) {
    state.environments.options = environmentOptions;
    state.environments.isLoading = false;
  },
  [types.RECEIVE_ENVIRONMENTS_DATA_ERROR](state) {
    state.environments.options = [];
    state.environments.isLoading = false;
  },

  // Logs data
  [types.REQUEST_LOGS_DATA](state) {
    state.timeRange.current = convertToFixedRange(state.timeRange.selected);

    state.logs.lines = [];
    state.logs.isLoading = true;

    // start pagination from the beginning
    state.logs.cursor = null;
    state.logs.isComplete = false;
  },
  [types.RECEIVE_LOGS_DATA_SUCCESS](state, { logs = [], cursor }) {
    state.logs.lines = logs.map(mapLine);
    state.logs.isLoading = false;
    state.logs.cursor = cursor;

    if (!cursor) {
      state.logs.isComplete = true;
    }
  },
  [types.RECEIVE_LOGS_DATA_ERROR](state) {
    state.logs.lines = [];
    state.logs.isLoading = false;
  },

  [types.REQUEST_LOGS_DATA_PREPEND](state) {
    state.logs.isLoading = true;
  },
  [types.RECEIVE_LOGS_DATA_PREPEND_SUCCESS](state, { logs = [], cursor }) {
    const lines = logs.map(mapLine);
    state.logs.lines = lines.concat(state.logs.lines);
    state.logs.isLoading = false;
    state.logs.cursor = cursor;

    if (!cursor) {
      state.logs.isComplete = true;
    }
  },
  [types.RECEIVE_LOGS_DATA_PREPEND_ERROR](state) {
    state.logs.isLoading = false;
  },

  // Pods data
  [types.SET_CURRENT_POD_NAME](state, podName) {
    state.pods.current = podName;
  },
  [types.REQUEST_PODS_DATA](state) {
    state.pods.options = [];
  },
  [types.RECEIVE_PODS_DATA_SUCCESS](state, podOptions) {
    state.pods.options = podOptions;
  },
  [types.RECEIVE_PODS_DATA_ERROR](state) {
    state.pods.options = [];
  },
};
