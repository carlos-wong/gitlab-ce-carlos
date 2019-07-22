import Vue from 'vue';
import { __ } from '../locale';
import createFlash from '../flash';
import axios from '../lib/utils/axios_utils';
import DivergenceGraph from './components/divergence_graph.vue';

export function createGraphVueApp(el, data, maxCommits) {
  return new Vue({
    el,
    render(h) {
      return h(DivergenceGraph, {
        props: {
          defaultBranch: 'master',
          distance: data.distance ? parseInt(data.distance, 10) : null,
          aheadCount: parseInt(data.ahead, 10),
          behindCount: parseInt(data.behind, 10),
          maxCommits,
        },
      });
    },
  });
}

export default endpoint => {
  const names = [...document.querySelectorAll('.js-branch-item')].map(
    ({ dataset }) => dataset.name,
  );
  return axios
    .get(endpoint, {
      params: { names },
    })
    .then(({ data }) => {
      const maxCommits = Object.entries(data).reduce((acc, [, val]) => {
        const max = Math.max(...Object.values(val));
        return max > acc ? max : acc;
      }, 100);

      Object.entries(data).forEach(([branchName, val]) => {
        const el = document.querySelector(
          `[data-name="${branchName}"] .js-branch-divergence-graph`,
        );

        if (!el) return;

        createGraphVueApp(el, val, maxCommits);
      });
    })
    .catch(() =>
      createFlash(__('Error fetching diverging counts for branches. Please try again.')),
    );
};
