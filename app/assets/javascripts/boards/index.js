import PortalVue from 'portal-vue';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import BoardApp from '~/boards/components/board_app.vue';
import '~/boards/filters/due_date_filters';
import { issuableTypes } from '~/boards/constants';
import store from '~/boards/stores';
import {
  NavigationType,
  isLoggedIn,
  parseBoolean,
  convertObjectPropsToCamelCase,
} from '~/lib/utils/common_utils';
import { queryToObject } from '~/lib/utils/url_utility';
import { fullBoardId } from './boards_util';
import { gqlClient } from './graphql';

Vue.use(VueApollo);
Vue.use(PortalVue);

const apolloProvider = new VueApollo({
  defaultClient: gqlClient,
});

function mountBoardApp(el) {
  const { boardId, groupId, fullPath, rootPath } = el.dataset;

  const rawFilterParams = queryToObject(window.location.search, { gatherArrays: true });

  const initialFilterParams = {
    ...convertObjectPropsToCamelCase(rawFilterParams),
  };

  store.dispatch('fetchBoard', {
    fullPath,
    fullBoardId: fullBoardId(boardId),
    boardType: el.dataset.parent,
  });

  store.dispatch('setInitialBoardData', {
    boardId,
    fullBoardId: fullBoardId(boardId),
    fullPath,
    boardType: el.dataset.parent,
    disabled: parseBoolean(el.dataset.disabled) || true,
    issuableType: issuableTypes.issue,
  });

  // eslint-disable-next-line no-new
  new Vue({
    el,
    name: 'BoardAppRoot',
    store,
    apolloProvider,
    provide: {
      disabled: parseBoolean(el.dataset.disabled),
      boardId,
      groupId: Number(groupId),
      rootPath,
      fullPath,
      initialFilterParams,
      boardBaseUrl: el.dataset.boardBaseUrl,
      boardType: el.dataset.parent,
      currentUserId: gon.current_user_id || null,
      boardWeight: el.dataset.boardWeight ? parseInt(el.dataset.boardWeight, 10) : null,
      labelsManagePath: el.dataset.labelsManagePath,
      labelsFilterBasePath: el.dataset.labelsFilterBasePath,
      releasesFetchPath: el.dataset.releasesFetchPath,
      timeTrackingLimitToHours: parseBoolean(el.dataset.timeTrackingLimitToHours),
      issuableType: issuableTypes.issue,
      emailsDisabled: parseBoolean(el.dataset.emailsDisabled),
      hasScope: parseBoolean(el.dataset.hasScope),
      hasMissingBoards: parseBoolean(el.dataset.hasMissingBoards),
      weights: el.dataset.weights ? JSON.parse(el.dataset.weights) : [],
      // Permissions
      canUpdate: parseBoolean(el.dataset.canUpdate),
      canAdminList: parseBoolean(el.dataset.canAdminList),
      canAdminBoard: parseBoolean(el.dataset.canAdminBoard),
      allowLabelCreate: parseBoolean(el.dataset.canUpdate),
      allowLabelEdit: parseBoolean(el.dataset.canUpdate),
      isSignedIn: isLoggedIn(),
      // Features
      multipleAssigneesFeatureAvailable: parseBoolean(el.dataset.multipleAssigneesFeatureAvailable),
      epicFeatureAvailable: parseBoolean(el.dataset.epicFeatureAvailable),
      iterationFeatureAvailable: parseBoolean(el.dataset.iterationFeatureAvailable),
      weightFeatureAvailable: parseBoolean(el.dataset.weightFeatureAvailable),
      scopedLabelsAvailable: parseBoolean(el.dataset.scopedLabels),
      milestoneListsAvailable: parseBoolean(el.dataset.milestoneListsAvailable),
      assigneeListsAvailable: parseBoolean(el.dataset.assigneeListsAvailable),
      iterationListsAvailable: parseBoolean(el.dataset.iterationListsAvailable),
      allowScopedLabels: parseBoolean(el.dataset.scopedLabels),
      swimlanesFeatureAvailable: gon.licensed_features?.swimlanes,
      multipleIssueBoardsAvailable: parseBoolean(el.dataset.multipleBoardsAvailable),
      scopedIssueBoardFeatureEnabled: parseBoolean(el.dataset.scopedIssueBoardFeatureEnabled),
    },
    render: (createComponent) => createComponent(BoardApp),
  });
}

export default () => {
  const $boardApp = document.getElementById('js-issuable-board-app');

  // check for browser back and trigger a hard reload to circumvent browser caching.
  window.addEventListener('pageshow', (event) => {
    const isNavTypeBackForward =
      window.performance && window.performance.navigation.type === NavigationType.TYPE_BACK_FORWARD;

    if (event.persisted || isNavTypeBackForward) {
      window.location.reload();
    }
  });

  mountBoardApp($boardApp);
};
