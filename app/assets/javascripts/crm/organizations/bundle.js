import { GlToast } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import VueRouter from 'vue-router';
import createDefaultClient from '~/lib/graphql';
import CrmOrganizationsRoot from './components/organizations_root.vue';
import routes from './routes';

Vue.use(VueApollo);
Vue.use(VueRouter);
Vue.use(GlToast);

export default () => {
  const el = document.getElementById('js-crm-organizations-app');

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  if (!el) {
    return false;
  }

  const { basePath, canAdminCrmOrganization, groupFullPath, groupId, groupIssuesPath } = el.dataset;

  const router = new VueRouter({
    base: basePath,
    mode: 'history',
    routes,
  });

  return new Vue({
    el,
    router,
    apolloProvider,
    provide: { canAdminCrmOrganization, groupFullPath, groupId, groupIssuesPath },
    render(createElement) {
      return createElement(CrmOrganizationsRoot);
    },
  });
};
