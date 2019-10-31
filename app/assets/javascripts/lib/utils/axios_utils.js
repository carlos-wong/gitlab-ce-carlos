import axios from 'axios';
import csrf from './csrf';
import suppressAjaxErrorsDuringNavigation from './suppress_ajax_errors_during_navigation';

axios.defaults.headers.common[csrf.headerKey] = csrf.token;
// Used by Rails to check if it is a valid XHR request
axios.defaults.headers.common['X-Requested-With'] = 'XMLHttpRequest';

// Maintain a global counter for active requests
// see: spec/support/wait_for_requests.rb
axios.interceptors.request.use(config => {
  window.pendingRequests = window.pendingRequests || 0;
  window.pendingRequests += 1;
  return config;
});

// Remove the global counter
axios.interceptors.response.use(
  response => {
    window.pendingRequests -= 1;
    return response;
  },
  err => {
    window.pendingRequests -= 1;
    return Promise.reject(err);
  },
);

let isUserNavigating = false;
window.addEventListener('beforeunload', () => {
  isUserNavigating = true;
});

// Ignore AJAX errors caused by requests
// being cancelled due to browser navigation
const { gon } = window;
const featureFlagEnabled = gon && gon.features && gon.features.suppressAjaxNavigationErrors;
axios.interceptors.response.use(
  response => response,
  err => suppressAjaxErrorsDuringNavigation(err, isUserNavigating, featureFlagEnabled),
);

export default axios;

/**
 * @return The adapter that axios uses for dispatching requests. This may be overwritten in tests.
 *
 * @see https://github.com/axios/axios/tree/master/lib/adapters
 * @see https://github.com/ctimmerm/axios-mock-adapter/blob/v1.12.0/src/index.js#L39
 */
export const getDefaultAdapter = () => axios.defaults.adapter;
