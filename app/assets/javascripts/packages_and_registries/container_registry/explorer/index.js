import { GlToast } from '@gitlab/ui';
import Vue from 'vue';
import { parseBoolean } from '~/lib/utils/common_utils';
import PerformancePlugin from '~/performance/vue_performance_plugin';
import Translate from '~/vue_shared/translate';
import RegistryBreadcrumb from '~/packages_and_registries/shared/components/registry_breadcrumb.vue';
import { renderBreadcrumb } from '~/packages_and_registries/shared/utils';
import { apolloProvider } from './graphql/index';
import RegistryExplorer from './pages/index.vue';
import createRouter from './router';

Vue.use(Translate);
Vue.use(GlToast);

Vue.use(PerformancePlugin, {
  components: [
    'RegistryListPage',
    'ListHeader',
    'ImageListRow',
    'RegistryDetailsPage',
    'DetailsHeader',
    'TagsList',
  ],
});

export default () => {
  const el = document.getElementById('js-container-registry');

  if (!el) {
    return null;
  }

  const {
    endpoint,
    expirationPolicy,
    isGroupPage,
    isAdmin,
    showCleanupPolicyLink,
    showUnfinishedTagCleanupCallout,
    connectionError,
    invalidPathError,
    ...config
  } = el.dataset;

  // This is a mini state to help the breadcrumb have the correct name in the details page
  const breadCrumbState = Vue.observable({
    name: '',
    updateName(value) {
      this.name = value;
    },
  });

  const router = createRouter(endpoint, breadCrumbState);

  const attachMainComponent = () =>
    new Vue({
      el,
      router,
      apolloProvider,
      components: {
        RegistryExplorer,
      },
      provide() {
        return {
          breadCrumbState,
          config: {
            ...config,
            expirationPolicy: expirationPolicy ? JSON.parse(expirationPolicy) : undefined,
            isGroupPage: parseBoolean(isGroupPage),
            isAdmin: parseBoolean(isAdmin),
            showCleanupPolicyLink: parseBoolean(showCleanupPolicyLink),
            showUnfinishedTagCleanupCallout: parseBoolean(showUnfinishedTagCleanupCallout),
            connectionError: parseBoolean(connectionError),
            invalidPathError: parseBoolean(invalidPathError),
          },
          /* eslint-disable @gitlab/require-i18n-strings */
          dockerBuildCommand: `docker build -t ${config.repositoryUrl} .`,
          dockerPushCommand: `docker push ${config.repositoryUrl}`,
          dockerLoginCommand: `docker login ${config.registryHostUrlWithPort}`,
          /* eslint-enable @gitlab/require-i18n-strings */
        };
      },
      render(createElement) {
        return createElement('registry-explorer');
      },
    });

  return {
    attachBreadcrumb: renderBreadcrumb(router, apolloProvider, RegistryBreadcrumb),
    attachMainComponent,
  };
};
