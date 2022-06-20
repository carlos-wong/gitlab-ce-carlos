import MockAdapter from 'axios-mock-adapter';
import testAction from 'helpers/vuex_action_helper';
import * as actions from '~/contributors/stores/actions';
import * as types from '~/contributors/stores/mutation_types';
import createFlash from '~/flash';
import axios from '~/lib/utils/axios_utils';

jest.mock('~/flash.js');

describe('Contributors store actions', () => {
  describe('fetchChartData', () => {
    let mock;
    const endpoint = '/contributors';
    const chartData = { '2017-11': 0, '2017-12': 2 };

    beforeEach(() => {
      mock = new MockAdapter(axios);
    });

    afterEach(() => {
      mock.restore();
    });

    it('should commit SET_CHART_DATA with received response', () => {
      mock.onGet().reply(200, chartData);

      return testAction(
        actions.fetchChartData,
        { endpoint },
        {},
        [
          { type: types.SET_LOADING_STATE, payload: true },
          { type: types.SET_CHART_DATA, payload: chartData },
          { type: types.SET_LOADING_STATE, payload: false },
        ],
        [],
      );
    });

    it('should show flash on API error', async () => {
      mock.onGet().reply(400, 'Not Found');

      await testAction(
        actions.fetchChartData,
        { endpoint },
        {},
        [{ type: types.SET_LOADING_STATE, payload: true }],
        [],
      );
      expect(createFlash).toHaveBeenCalledWith({
        message: expect.stringMatching('error'),
      });
    });
  });
});
