/* Common setup for both unit and integration test environments */
import { config as testUtilsConfig } from '@vue/test-utils';
import * as jqueryMatchers from 'custom-jquery-matchers';
import Vue from 'vue';
import 'jquery';
import Translate from '~/vue_shared/translate';
import setWindowLocation from './set_window_location_helper';
import { setGlobalDateToFakeDate } from './fake_date';
import { TEST_HOST } from './test_constants';
import * as customMatchers from './matchers';

import './dom_shims';
import './jquery';
import '~/commons/bootstrap';

// This module has some fairly decent visual test coverage in it's own repository.
jest.mock('@gitlab/favicon-overlay');
jest.mock('~/lib/utils/axios_utils', () => jest.requireActual('helpers/mocks/axios_utils'));

process.on('unhandledRejection', global.promiseRejectionHandler);

// Fake the `Date` for the rest of the jest spec runtime environment.
// https://gitlab.com/gitlab-org/gitlab/-/merge_requests/39496#note_503084332
setGlobalDateToFakeDate();

Vue.config.devtools = false;
Vue.config.productionTip = false;

Vue.use(Translate);

const JQUERY_MATCHERS_TO_EXCLUDE = ['toHaveLength', 'toExist'];

// custom-jquery-matchers was written for an old Jest version, we need to make it compatible
Object.entries(jqueryMatchers).forEach(([matcherName, matcherFactory]) => {
  // Exclude these jQuery matchers
  if (JQUERY_MATCHERS_TO_EXCLUDE.includes(matcherName)) {
    return;
  }

  expect.extend({
    [matcherName]: matcherFactory().compare,
  });
});

expect.extend(customMatchers);

testUtilsConfig.deprecationWarningHandler = (method, message) => {
  const ALLOWED_DEPRECATED_METHODS = [
    // https://gitlab.com/gitlab-org/gitlab/-/issues/295679
    'finding components with `find` or `get`',

    // https://gitlab.com/gitlab-org/gitlab/-/issues/295680
    'finding components with `findAll`',
  ];
  if (!ALLOWED_DEPRECATED_METHODS.includes(method)) {
    global.console.error(message);
  }
};

Object.assign(global, {
  requestIdleCallback(cb) {
    const start = Date.now();
    return setTimeout(() => {
      cb({
        didTimeout: false,
        timeRemaining: () => Math.max(0, 50 - (Date.now() - start)),
      });
    });
  },
  cancelIdleCallback(id) {
    clearTimeout(id);
  },
});

beforeEach(() => {
  // make sure that each test actually tests something
  // see https://jestjs.io/docs/en/expect#expecthasassertions
  expect.hasAssertions();

  // Reset the mocked window.location. This ensures tests don't interfere with
  // each other, and removes the need to tidy up if it was changed for a given
  // test.
  setWindowLocation(TEST_HOST);
});
