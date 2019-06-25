import Vue from 'vue';
import createRouter from './router';
import App from './components/app.vue';
import Breadcrumbs from './components/breadcrumbs.vue';
import apolloProvider from './graphql';
import { setTitle } from './utils/title';

export default function setupVueRepositoryList() {
  const el = document.getElementById('js-tree-list');
  const { projectPath, projectShortPath, ref, fullName } = el.dataset;
  const router = createRouter(projectPath, ref);

  apolloProvider.clients.defaultClient.cache.writeData({
    data: {
      projectPath,
      projectShortPath,
      ref,
    },
  });

  router.afterEach(({ params: { pathMatch } }) => {
    const isRoot = pathMatch === undefined || pathMatch === '/';

    setTitle(pathMatch, ref, fullName);

    if (!isRoot) {
      document
        .querySelectorAll('.js-keep-hidden-on-navigation')
        .forEach(elem => elem.classList.add('hidden'));
    }

    document
      .querySelectorAll('.js-hide-on-navigation')
      .forEach(elem => elem.classList.toggle('hidden', !isRoot));
  });

  // eslint-disable-next-line no-new
  new Vue({
    el: document.getElementById('js-repo-breadcrumb'),
    router,
    apolloProvider,
    render(h) {
      return h(Breadcrumbs, {
        props: {
          currentPath: this.$route.params.pathMatch,
        },
      });
    },
  });

  return new Vue({
    el,
    router,
    apolloProvider,
    render(h) {
      return h(App);
    },
  });
}
