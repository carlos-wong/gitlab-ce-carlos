import Vue from 'vue';
import VueApollo from 'vue-apollo';
import MergeRequestExperienceSurveyApp from '~/surveys/merge_request_experience/app.vue';
import createDefaultClient from '~/lib/graphql';
import Translate from '~/vue_shared/translate';

Vue.use(Translate);
Vue.use(VueApollo);

export const startMrSurveyApp = () => {
  let channel = null;

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  const app = new Vue({
    apolloProvider,
    data() {
      return {
        hidden: false,
      };
    },
    render(h) {
      if (this.hidden) return null;
      return h(MergeRequestExperienceSurveyApp, {
        on: {
          close: () => {
            channel?.postMessage('close');
            app.hidden = true;
          },
          rate: () => {
            channel?.postMessage('close');
          },
        },
      });
    },
  });

  app.$mount('#js-mr-experience-survey');

  if (window.BroadcastChannel) {
    channel = new BroadcastChannel('mr_survey');
    channel.addEventListener('message', ({ data }) => {
      if (data === 'close') {
        app.hidden = true;
        channel.close();
        channel = null;
      }
    });
  }
};
