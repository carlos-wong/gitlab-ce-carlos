import MockAdapter from 'axios-mock-adapter';
import { TEST_HOST } from 'helpers/test_constants';
import testAction from 'helpers/vuex_action_helper';
import { PING_USAGE_PREVIEW_KEY } from '~/ide/constants';
import * as actions from '~/ide/stores/modules/clientside/actions';
import axios from '~/lib/utils/axios_utils';

const TEST_PROJECT_URL = `${TEST_HOST}/lorem/ipsum`;
const TEST_USAGE_URL = `${TEST_PROJECT_URL}/service_ping/${PING_USAGE_PREVIEW_KEY}`;

describe('IDE store module clientside actions', () => {
  let rootGetters;
  let mock;

  beforeEach(() => {
    rootGetters = {
      currentProject: {
        web_url: TEST_PROJECT_URL,
      },
    };
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  describe('pingUsage', () => {
    it('posts to usage endpoint', async () => {
      const usageSpy = jest.fn(() => [200]);

      mock.onPost(TEST_USAGE_URL).reply(() => usageSpy());

      await testAction(actions.pingUsage, PING_USAGE_PREVIEW_KEY, rootGetters, [], []);
      expect(usageSpy).toHaveBeenCalled();
    });
  });
});
