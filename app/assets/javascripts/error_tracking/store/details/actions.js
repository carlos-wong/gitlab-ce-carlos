import service from '../../services';
import * as types from './mutation_types';
import createFlash from '~/flash';
import Poll from '~/lib/utils/poll';
import { __ } from '~/locale';

let stackTracePoll;

const stopPolling = poll => {
  if (poll) poll.stop();
};

export function startPollingStacktrace({ commit }, endpoint) {
  stackTracePoll = new Poll({
    resource: service,
    method: 'getSentryData',
    data: { endpoint },
    successCallback: ({ data }) => {
      if (!data) {
        return;
      }
      commit(types.SET_STACKTRACE_DATA, data.error);
      commit(types.SET_LOADING_STACKTRACE, false);

      stopPolling(stackTracePoll);
    },
    errorCallback: () => {
      commit(types.SET_LOADING_STACKTRACE, false);
      createFlash(__('Failed to load stacktrace.'));
    },
  });

  stackTracePoll.makeRequest();
}

export default () => {};
