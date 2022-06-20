import { ApolloClient, InMemoryCache, ApolloLink, HttpLink } from '@apollo/client/core';
import { BatchHttpLink } from '@apollo/client/link/batch-http';
import { createUploadLink } from 'apollo-upload-client';
import ActionCableLink from '~/actioncable_link';
import { apolloCaptchaLink } from '~/captcha/apollo_captcha_link';
import possibleTypes from '~/graphql_shared/possible_types.json';
import { StartupJSLink } from '~/lib/utils/apollo_startup_js_link';
import csrf from '~/lib/utils/csrf';
import { objectToQuery, queryToObject } from '~/lib/utils/url_utility';
import PerformanceBarService from '~/performance_bar/services/performance_bar_service';
import { getInstrumentationLink } from './apollo/instrumentation_link';
import { getSuppressNetworkErrorsDuringNavigationLink } from './apollo/suppress_network_errors_during_navigation_link';

export const fetchPolicies = {
  CACHE_FIRST: 'cache-first',
  CACHE_AND_NETWORK: 'cache-and-network',
  NETWORK_ONLY: 'network-only',
  NO_CACHE: 'no-cache',
  CACHE_ONLY: 'cache-only',
};

export const typePolicies = {
  Repository: {
    merge: true,
  },
  UserPermissions: {
    merge: true,
  },
  MergeRequestPermissions: {
    merge: true,
  },
  ContainerRepositoryConnection: {
    merge: true,
  },
  TimelogConnection: {
    merge: true,
  },
  BranchList: {
    merge: true,
  },
  InstanceSecurityDashboard: {
    merge: true,
  },
  PipelinePermissions: {
    merge: true,
  },
  DesignCollection: {
    merge: true,
  },
  TreeEntry: {
    keyFields: ['webPath'],
  },
};

export const stripWhitespaceFromQuery = (url, path) => {
  /* eslint-disable-next-line no-unused-vars */
  const [_, params] = url.split(path);

  if (!params) {
    return url;
  }

  const decoded = decodeURIComponent(params);
  const paramsObj = queryToObject(decoded);

  if (!paramsObj.query) {
    return url;
  }

  const stripped = paramsObj.query
    .split(/\s+|\n/)
    .join(' ')
    .trim();
  paramsObj.query = stripped;

  const reassembled = objectToQuery(paramsObj);
  return `${path}?${reassembled}`;
};

const acs = [];

let pendingApolloMutations = 0;

// ### Why track pendingApolloMutations, but calculate pendingApolloRequests?
//
// In Apollo 2, we had a single link for counting operations.
//
// With Apollo 3, the `forward().map(...)` of deduped queries is never called.
// So, we resorted to calculating the sum of `inFlightLinkObservables?.size`.
// However! Mutations don't use `inFLightLinkObservables`, but since they are likely
// not deduped we can count them...
//
// https://gitlab.com/gitlab-org/gitlab/-/merge_requests/55062#note_838943715
// https://www.apollographql.com/docs/react/v2/networking/network-layer/#query-deduplication
Object.defineProperty(window, 'pendingApolloRequests', {
  get() {
    return acs.reduce(
      (sum, ac) => sum + (ac?.queryManager?.inFlightLinkObservables?.size || 0),
      pendingApolloMutations,
    );
  },
});

export default (resolvers = {}, config = {}) => {
  const {
    baseUrl,
    batchMax = 10,
    cacheConfig,
    fetchPolicy = fetchPolicies.CACHE_FIRST,
    typeDefs,
    path = '/api/graphql',
    useGet = false,
  } = config;
  let ac = null;
  let uri = `${gon.relative_url_root || ''}${path}`;

  if (baseUrl) {
    // Prepend baseUrl and ensure that `///` are replaced with `/`
    uri = `${baseUrl}${uri}`.replace(/\/{3,}/g, '/');
  }

  const httpOptions = {
    uri,
    headers: {
      [csrf.headerKey]: csrf.token,
    },
    // fetch won’t send cookies in older browsers, unless you set the credentials init option.
    // We set to `same-origin` which is default value in modern browsers.
    // See https://github.com/whatwg/fetch/pull/585 for more information.
    credentials: 'same-origin',
    batchMax,
  };

  /*
    This custom fetcher intervention is to deal with an issue where we are using GET to access
    eTag polling, but Apollo Client adds excessive whitespace, which causes the
    request to fail on certain self-hosted stacks. When we can move
    to subscriptions entirely or can land an upstream PR, this can be removed.

    Related links
    Bug report: https://gitlab.com/gitlab-org/gitlab/-/issues/329895
    Moving to subscriptions: https://gitlab.com/gitlab-org/gitlab/-/issues/332485
    Apollo Client issue: https://github.com/apollographql/apollo-feature-requests/issues/182
  */

  const fetchIntervention = (url, options) => {
    return fetch(stripWhitespaceFromQuery(url, uri), options);
  };

  const requestLink = ApolloLink.split(
    () => useGet,
    new HttpLink({ ...httpOptions, fetch: fetchIntervention }),
    new BatchHttpLink(httpOptions),
  );

  const uploadsLink = ApolloLink.split(
    (operation) => operation.getContext().hasUpload || operation.getContext().isSingleRequest,
    createUploadLink(httpOptions),
  );

  const performanceBarLink = new ApolloLink((operation, forward) => {
    return forward(operation).map((response) => {
      const httpResponse = operation.getContext().response;

      if (PerformanceBarService.interceptor) {
        PerformanceBarService.interceptor({
          config: {
            url: httpResponse.url,
          },
          headers: {
            'x-request-id': httpResponse.headers.get('x-request-id'),
            'x-gitlab-from-cache': httpResponse.headers.get('x-gitlab-from-cache'),
          },
        });
      }

      return response;
    });
  });

  const hasSubscriptionOperation = ({ query: { definitions } }) => {
    return definitions.some(
      ({ kind, operation }) => kind === 'OperationDefinition' && operation === 'subscription',
    );
  };

  const hasMutation = (operation) =>
    (operation?.query?.definitions || []).some((x) => x.operation === 'mutation');

  const requestCounterLink = new ApolloLink((operation, forward) => {
    if (hasMutation(operation)) {
      pendingApolloMutations += 1;
    }

    return forward(operation).map((response) => {
      if (hasMutation(operation)) {
        pendingApolloMutations -= 1;
      }
      return response;
    });
  });

  const appLink = ApolloLink.split(
    hasSubscriptionOperation,
    new ActionCableLink(),
    ApolloLink.from(
      [
        getSuppressNetworkErrorsDuringNavigationLink(),
        getInstrumentationLink(),
        requestCounterLink,
        performanceBarLink,
        new StartupJSLink(),
        apolloCaptchaLink,
        uploadsLink,
        requestLink,
      ].filter(Boolean),
    ),
  );

  ac = new ApolloClient({
    typeDefs,
    link: appLink,
    cache: new InMemoryCache({
      typePolicies,
      possibleTypes,
      ...cacheConfig,
    }),
    resolvers,
    defaultOptions: {
      query: {
        fetchPolicy,
      },
    },
  });

  acs.push(ac);

  return ac;
};
