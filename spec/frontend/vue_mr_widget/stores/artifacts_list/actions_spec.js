import MockAdapter from 'axios-mock-adapter';
import { TEST_HOST } from 'helpers/test_constants';
import testAction from 'helpers/vuex_action_helper';
import axios from '~/lib/utils/axios_utils';
import {
  setEndpoint,
  requestArtifacts,
  clearEtagPoll,
  stopPolling,
  fetchArtifacts,
  receiveArtifactsSuccess,
  receiveArtifactsError,
} from '~/vue_merge_request_widget/stores/artifacts_list/actions';
import * as types from '~/vue_merge_request_widget/stores/artifacts_list/mutation_types';
import state from '~/vue_merge_request_widget/stores/artifacts_list/state';

describe('Artifacts App Store Actions', () => {
  let mockedState;

  beforeEach(() => {
    mockedState = state();
  });

  describe('setEndpoint', () => {
    it('should commit SET_ENDPOINT mutation', () => {
      return testAction(
        setEndpoint,
        'endpoint.json',
        mockedState,
        [{ type: types.SET_ENDPOINT, payload: 'endpoint.json' }],
        [],
      );
    });
  });

  describe('requestArtifacts', () => {
    it('should commit REQUEST_ARTIFACTS mutation', () => {
      return testAction(
        requestArtifacts,
        null,
        mockedState,
        [{ type: types.REQUEST_ARTIFACTS }],
        [],
      );
    });
  });

  describe('fetchArtifacts', () => {
    let mock;

    beforeEach(() => {
      mockedState.endpoint = `${TEST_HOST}/endpoint.json`;
      mock = new MockAdapter(axios);
    });

    afterEach(() => {
      mock.restore();
      stopPolling();
      clearEtagPoll();
    });

    describe('success', () => {
      it('dispatches requestArtifacts and receiveArtifactsSuccess ', () => {
        mock.onGet(`${TEST_HOST}/endpoint.json`).replyOnce(200, [
          {
            text: 'result.txt',
            url: 'asda',
            job_name: 'generate-artifact',
            job_path: 'asda',
          },
        ]);

        return testAction(
          fetchArtifacts,
          null,
          mockedState,
          [],
          [
            {
              type: 'requestArtifacts',
            },
            {
              payload: {
                data: [
                  {
                    text: 'result.txt',
                    url: 'asda',
                    job_name: 'generate-artifact',
                    job_path: 'asda',
                  },
                ],
                status: 200,
              },
              type: 'receiveArtifactsSuccess',
            },
          ],
        );
      });
    });

    describe('error', () => {
      beforeEach(() => {
        mock.onGet(`${TEST_HOST}/endpoint.json`).reply(500);
      });

      it('dispatches requestArtifacts and receiveArtifactsError ', () => {
        return testAction(
          fetchArtifacts,
          null,
          mockedState,
          [],
          [
            {
              type: 'requestArtifacts',
            },
            {
              type: 'receiveArtifactsError',
            },
          ],
        );
      });
    });
  });

  describe('receiveArtifactsSuccess', () => {
    it('should commit RECEIVE_ARTIFACTS_SUCCESS mutation with 200', () => {
      return testAction(
        receiveArtifactsSuccess,
        { data: { summary: {} }, status: 200 },
        mockedState,
        [{ type: types.RECEIVE_ARTIFACTS_SUCCESS, payload: { summary: {} } }],
        [],
      );
    });

    it('should not commit RECEIVE_ARTIFACTS_SUCCESS mutation with 204', () => {
      return testAction(
        receiveArtifactsSuccess,
        { data: { summary: {} }, status: 204 },
        mockedState,
        [],
        [],
      );
    });
  });

  describe('receiveArtifactsError', () => {
    it('should commit RECEIVE_ARTIFACTS_ERROR mutation', () => {
      return testAction(
        receiveArtifactsError,
        null,
        mockedState,
        [{ type: types.RECEIVE_ARTIFACTS_ERROR }],
        [],
      );
    });
  });
});
