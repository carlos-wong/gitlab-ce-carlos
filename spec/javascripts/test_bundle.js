/* eslint-disable
  jasmine/no-global-setup, jasmine/no-unsafe-spy, no-underscore-dangle, no-console
*/

import $ from 'jquery';
import 'vendor/jasmine-jquery';
import '~/commons';
import Vue from 'vue';
import VueResource from 'vue-resource';
import Translate from '~/vue_shared/translate';
import CheckEE from '~/vue_shared/mixins/is_ee';
import jasmineDiff from 'jasmine-diff';

import { getDefaultAdapter } from '~/lib/utils/axios_utils';
import { FIXTURES_PATH, TEST_HOST } from './test_constants';

import customMatchers from './matchers';

const isHeadlessChrome = /\bHeadlessChrome\//.test(navigator.userAgent);
Vue.config.devtools = !isHeadlessChrome;
Vue.config.productionTip = false;

let hasVueWarnings = false;
Vue.config.warnHandler = (msg, vm, trace) => {
  // The following workaround is necessary, so we are able to use setProps from Vue test utils
  // see https://github.com/vuejs/vue-test-utils/issues/631#issuecomment-421108344
  const currentStack = new Error().stack;
  const isInVueTestUtils = currentStack
    .split('\n')
    .some(line => line.startsWith('    at VueWrapper.setProps ('));
  if (isInVueTestUtils) {
    return;
  }

  hasVueWarnings = true;
  fail(`${msg}${trace}`);
};

let hasVueErrors = false;
Vue.config.errorHandler = function(err) {
  hasVueErrors = true;
  fail(err);
};

Vue.use(VueResource);
Vue.use(Translate);
Vue.use(CheckEE);

// enable test fixtures
jasmine.getFixtures().fixturesPath = FIXTURES_PATH;
jasmine.getJSONFixtures().fixturesPath = FIXTURES_PATH;

beforeAll(() => {
  jasmine.addMatchers(
    jasmineDiff(jasmine, {
      colors: window.__karma__.config.color,
      inline: window.__karma__.config.color,
    }),
  );
  jasmine.addMatchers(customMatchers);
});

// globalize common libraries
window.$ = $;
window.jQuery = window.$;

// stub expected globals
window.gl = window.gl || {};
window.gl.TEST_HOST = TEST_HOST;
window.gon = window.gon || {};
window.gon.test_env = true;
window.gon.ee = process.env.IS_GITLAB_EE;
gon.relative_url_root = '';

let hasUnhandledPromiseRejections = false;

window.addEventListener('unhandledrejection', event => {
  hasUnhandledPromiseRejections = true;
  console.error('Unhandled promise rejection:');
  console.error(event.reason.stack || event.reason);
});

// Add global function to spy on a module's dependencies via rewire
window.spyOnDependency = (module, name) => {
  const dependency = module.__GetDependency__(name);
  const spy = jasmine.createSpy(name, dependency);
  module.__Rewire__(name, spy);
  return spy;
};

// Reset any rewired modules after each test (see babel-plugin-rewire)
afterEach(__rewire_reset_all__); // eslint-disable-line

// HACK: Chrome 59 disconnects if there are too many synchronous tests in a row
// because it appears to lock up the thread that communicates to Karma's socket
// This async beforeEach gets called on every spec and releases the JS thread long
// enough for the socket to continue to communicate.
// The downside is that it creates a minor performance penalty in the time it takes
// to run our unit tests.
beforeEach(done => done());

const builtinVueHttpInterceptors = Vue.http.interceptors.slice();

beforeEach(() => {
  // restore interceptors so we have no remaining ones from previous tests
  Vue.http.interceptors = builtinVueHttpInterceptors.slice();
});

let longRunningTestTimeoutHandle;

beforeEach(done => {
  longRunningTestTimeoutHandle = setTimeout(() => {
    done.fail('Test is running too long!');
  }, 4000);
  done();
});

afterEach(() => {
  clearTimeout(longRunningTestTimeoutHandle);
});

const axiosDefaultAdapter = getDefaultAdapter();

// render all of our tests
const testContexts = [require.context('spec', true, /_spec$/)];

if (process.env.IS_GITLAB_EE) {
  testContexts.push(require.context('ee_spec', true, /_spec$/));
}

testContexts.forEach(context => {
  context.keys().forEach(path => {
    try {
      context(path);
    } catch (err) {
      console.log(err);
      console.error('[GL SPEC RUNNER ERROR] Unable to load spec: ', path);
      describe('Test bundle', function() {
        it(`includes '${path}'`, function() {
          expect(err).toBeNull();
        });
      });
    }
  });
});

describe('test errors', () => {
  beforeAll(done => {
    if (hasUnhandledPromiseRejections || hasVueWarnings || hasVueErrors) {
      setTimeout(done, 1000);
    } else {
      done();
    }
  });

  it('has no unhandled Promise rejections', () => {
    expect(hasUnhandledPromiseRejections).toBe(false);
  });

  it('has no Vue warnings', () => {
    expect(hasVueWarnings).toBe(false);
  });

  it('has no Vue error', () => {
    expect(hasVueErrors).toBe(false);
  });

  it('restores axios adapter after mocking', () => {
    if (getDefaultAdapter() !== axiosDefaultAdapter) {
      fail('axios adapter is not restored! Did you forget a restore() on MockAdapter?');
    }
  });
});

// if we're generating coverage reports, make sure to include all files so
// that we can catch files with 0% coverage
// see: https://github.com/deepsweet/istanbul-instrumenter-loader/issues/15
if (process.env.BABEL_ENV === 'coverage') {
  // exempt these files from the coverage report
  const troubleMakers = [
    './blob_edit/blob_bundle.js',
    './boards/components/modal/empty_state.vue',
    './boards/components/modal/footer.js',
    './boards/components/modal/header.js',
    './cycle_analytics/cycle_analytics_bundle.js',
    './cycle_analytics/components/stage_plan_component.js',
    './cycle_analytics/components/stage_staging_component.js',
    './cycle_analytics/components/stage_test_component.js',
    './commit/pipelines/pipelines_bundle.js',
    './diff_notes/diff_notes_bundle.js',
    './diff_notes/components/jump_to_discussion.js',
    './diff_notes/components/resolve_count.js',
    './dispatcher.js',
    './environments/environments_bundle.js',
    './graphs/graphs_bundle.js',
    './issuable/time_tracking/time_tracking_bundle.js',
    './main.js',
    './merge_conflicts/merge_conflicts_bundle.js',
    './merge_conflicts/components/inline_conflict_lines.js',
    './merge_conflicts/components/parallel_conflict_lines.js',
    './monitoring/monitoring_bundle.js',
    './network/network_bundle.js',
    './network/branch_graph.js',
    './profile/profile_bundle.js',
    './protected_branches/protected_branches_bundle.js',
    './snippet/snippet_bundle.js',
    './terminal/terminal_bundle.js',
    './users/users_bundle.js',
    './issue_show/index.js',
    './pages/admin/application_settings/show/index.js',
  ];

  describe('Uncovered files', function() {
    const sourceFilesContexts = [require.context('~', true, /\.(js|vue)$/)];

    if (process.env.IS_GITLAB_EE) {
      sourceFilesContexts.push(require.context('ee', true, /\.(js|vue)$/));
    }

    const allTestFiles = testContexts.reduce(
      (accumulator, context) => accumulator.concat(context.keys()),
      [],
    );

    $.holdReady(true);

    sourceFilesContexts.forEach(context => {
      context.keys().forEach(path => {
        // ignore if there is a matching spec file
        if (allTestFiles.indexOf(`${path.replace(/\.(js|vue)$/, '')}_spec`) > -1) {
          return;
        }

        it(`includes '${path}'`, function() {
          try {
            context(path);
          } catch (err) {
            if (troubleMakers.indexOf(path) === -1) {
              expect(err).toBeNull();
            }
          }
        });
      });
    });
  });
}
