import Vue from 'vue';

import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { EDITOR_APP_STATUS_LOADING } from './constants';
import { CODE_SNIPPET_SOURCE_SETTINGS } from './components/code_snippet_alert/constants';
import getCurrentBranch from './graphql/queries/client/current_branch.query.graphql';
import getAppStatus from './graphql/queries/client/app_status.query.graphql';
import getLastCommitBranch from './graphql/queries/client/last_commit_branch.query.graphql';
import getPipelineEtag from './graphql/queries/client/pipeline_etag.query.graphql';
import { resolvers } from './graphql/resolvers';
import typeDefs from './graphql/typedefs.graphql';
import PipelineEditorApp from './pipeline_editor_app.vue';

export const initPipelineEditor = (selector = '#js-pipeline-editor') => {
  const el = document.querySelector(selector);

  if (!el) {
    return null;
  }

  const {
    // Add to apollo cache as it can be updated by future queries
    initialBranchName,
    pipelineEtag,
    // Add to provide/inject API for static values
    ciConfigPath,
    ciExamplesHelpPagePath,
    ciHelpPagePath,
    ciLintPath,
    defaultBranch,
    emptyStateIllustrationPath,
    helpPaths,
    includesHelpPagePath,
    lintHelpPagePath,
    lintUnavailableHelpPagePath,
    needsHelpPagePath,
    newMergeRequestPath,
    pipelinePagePath,
    projectFullPath,
    projectPath,
    projectNamespace,
    runnerHelpPagePath,
    simulatePipelineHelpPagePath,
    totalBranches,
    validateTabIllustrationPath,
    ymlHelpPagePath,
  } = el.dataset;

  const configurationPaths = Object.fromEntries(
    Object.entries(CODE_SNIPPET_SOURCE_SETTINGS).map(([source, { datasetKey }]) => [
      source,
      el.dataset[datasetKey],
    ]),
  );

  Vue.use(VueApollo);

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(resolvers, {
      typeDefs,
      useGet: true,
    }),
  });
  const { cache } = apolloProvider.clients.defaultClient;

  cache.writeQuery({
    query: getAppStatus,
    data: {
      app: {
        __typename: 'PipelineEditorApp',
        status: EDITOR_APP_STATUS_LOADING,
      },
    },
  });

  cache.writeQuery({
    query: getCurrentBranch,
    data: {
      workBranches: {
        __typename: 'BranchList',
        current: {
          __typename: 'WorkBranch',
          name: initialBranchName || defaultBranch,
        },
      },
    },
  });

  cache.writeQuery({
    query: getLastCommitBranch,
    data: {
      workBranches: {
        __typename: 'BranchList',
        lastCommit: {
          __typename: 'WorkBranch',
          name: '',
        },
      },
    },
  });

  cache.writeQuery({
    query: getPipelineEtag,
    data: {
      etags: {
        __typename: 'EtagValues',
        pipeline: pipelineEtag,
      },
    },
  });

  return new Vue({
    el,
    apolloProvider,
    provide: {
      ciConfigPath,
      ciExamplesHelpPagePath,
      ciHelpPagePath,
      ciLintPath,
      configurationPaths,
      dataMethod: 'graphql',
      defaultBranch,
      emptyStateIllustrationPath,
      helpPaths,
      includesHelpPagePath,
      lintHelpPagePath,
      lintUnavailableHelpPagePath,
      needsHelpPagePath,
      newMergeRequestPath,
      pipelinePagePath,
      projectFullPath,
      projectPath,
      projectNamespace,
      runnerHelpPagePath,
      simulatePipelineHelpPagePath,
      totalBranches: parseInt(totalBranches, 10),
      validateTabIllustrationPath,
      ymlHelpPagePath,
    },
    render(h) {
      return h(PipelineEditorApp);
    },
  });
};
