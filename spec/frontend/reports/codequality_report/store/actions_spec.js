import MockAdapter from 'axios-mock-adapter';
import testAction from 'helpers/vuex_action_helper';
import { TEST_HOST } from 'spec/test_constants';
import axios from '~/lib/utils/axios_utils';
import createStore from '~/reports/codequality_report/store';
import * as actions from '~/reports/codequality_report/store/actions';
import * as types from '~/reports/codequality_report/store/mutation_types';
import { STATUS_NOT_FOUND } from '~/reports/constants';
import { reportIssues, parsedReportIssues } from '../mock_data';

const pollInterval = 123;
const pollIntervalHeader = {
  'Poll-Interval': pollInterval,
};

describe('Codequality Reports actions', () => {
  let localState;
  let localStore;

  beforeEach(() => {
    localStore = createStore();
    localState = localStore.state;
  });

  describe('setPaths', () => {
    it('should commit SET_PATHS mutation', () => {
      const paths = {
        baseBlobPath: 'baseBlobPath',
        headBlobPath: 'headBlobPath',
        reportsPath: 'reportsPath',
        helpPath: 'codequalityHelpPath',
      };

      return testAction(
        actions.setPaths,
        paths,
        localState,
        [{ type: types.SET_PATHS, payload: paths }],
        [],
      );
    });
  });

  describe('fetchReports', () => {
    const endpoint = `${TEST_HOST}/codequality_reports.json`;
    let mock;

    beforeEach(() => {
      localState.reportsPath = endpoint;
      mock = new MockAdapter(axios);
    });

    afterEach(() => {
      mock.restore();
    });

    describe('on success', () => {
      it('commits REQUEST_REPORTS and dispatches receiveReportsSuccess', () => {
        mock.onGet(endpoint).reply(200, reportIssues);

        return testAction(
          actions.fetchReports,
          null,
          localState,
          [{ type: types.REQUEST_REPORTS }],
          [
            {
              payload: parsedReportIssues,
              type: 'receiveReportsSuccess',
            },
          ],
        );
      });
    });

    describe('on error', () => {
      it('commits REQUEST_REPORTS and dispatches receiveReportsError', () => {
        mock.onGet(endpoint).reply(500);

        return testAction(
          actions.fetchReports,
          null,
          localState,
          [{ type: types.REQUEST_REPORTS }],
          [{ type: 'receiveReportsError', payload: expect.any(Error) }],
        );
      });
    });

    describe('when base report is not found', () => {
      it('commits REQUEST_REPORTS and dispatches receiveReportsError', () => {
        const data = { status: STATUS_NOT_FOUND };
        mock.onGet(`${TEST_HOST}/codequality_reports.json`).reply(200, data);

        return testAction(
          actions.fetchReports,
          null,
          localState,
          [{ type: types.REQUEST_REPORTS }],
          [{ type: 'receiveReportsError', payload: data }],
        );
      });
    });

    describe('while waiting for report results', () => {
      it('continues polling until it receives data', () => {
        mock
          .onGet(endpoint)
          .replyOnce(204, undefined, pollIntervalHeader)
          .onGet(endpoint)
          .reply(200, reportIssues);

        return Promise.all([
          testAction(
            actions.fetchReports,
            null,
            localState,
            [{ type: types.REQUEST_REPORTS }],
            [
              {
                payload: parsedReportIssues,
                type: 'receiveReportsSuccess',
              },
            ],
          ),
          axios
            // wait for initial NO_CONTENT response to be fulfilled
            .waitForAll()
            .then(() => {
              jest.advanceTimersByTime(pollInterval);
            }),
        ]);
      });

      it('continues polling until it receives an error', () => {
        mock
          .onGet(endpoint)
          .replyOnce(204, undefined, pollIntervalHeader)
          .onGet(endpoint)
          .reply(500);

        return Promise.all([
          testAction(
            actions.fetchReports,
            null,
            localState,
            [{ type: types.REQUEST_REPORTS }],
            [{ type: 'receiveReportsError', payload: expect.any(Error) }],
          ),
          axios
            // wait for initial NO_CONTENT response to be fulfilled
            .waitForAll()
            .then(() => {
              jest.advanceTimersByTime(pollInterval);
            }),
        ]);
      });
    });
  });

  describe('receiveReportsSuccess', () => {
    it('commits RECEIVE_REPORTS_SUCCESS', () => {
      const data = { issues: [] };

      return testAction(
        actions.receiveReportsSuccess,
        data,
        localState,
        [{ type: types.RECEIVE_REPORTS_SUCCESS, payload: data }],
        [],
      );
    });
  });

  describe('receiveReportsError', () => {
    it('commits RECEIVE_REPORTS_ERROR', () => {
      return testAction(
        actions.receiveReportsError,
        null,
        localState,
        [{ type: types.RECEIVE_REPORTS_ERROR, payload: null }],
        [],
      );
    });
  });
});
