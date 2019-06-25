import $ from 'jquery';
import Vue from 'vue';

import Flash from '~/flash';
import { __ } from '~/locale';
import './models/label';
import './models/assignee';

import FilteredSearchBoards from './filtered_search_boards';
import eventHub from './eventhub';
import sidebarEventHub from '~/sidebar/event_hub';
import './models/issue';
import './models/list';
import './models/milestone';
import './models/project';
import boardsStore from './stores/boards_store';
import ModalStore from './stores/modal_store';
import BoardService from './services/board_service';
import modalMixin from './mixins/modal_mixins';
import './filters/due_date_filters';
import Board from './components/board';
import BoardSidebar from './components/board_sidebar';
import initNewListDropdown from './components/new_list_dropdown';
import BoardAddIssuesModal from './components/modal/index.vue';
import '~/vue_shared/vue_resource_interceptor';
import {
  NavigationType,
  convertObjectPropsToCamelCase,
  parseBoolean,
} from '~/lib/utils/common_utils';

let issueBoardsApp;

export default () => {
  const $boardApp = document.getElementById('board-app');

  // check for browser back and trigger a hard reload to circumvent browser caching.
  window.addEventListener('pageshow', event => {
    const isNavTypeBackForward =
      window.performance && window.performance.navigation.type === NavigationType.TYPE_BACK_FORWARD;

    if (event.persisted || isNavTypeBackForward) {
      window.location.reload();
    }
  });

  if (issueBoardsApp) {
    issueBoardsApp.$destroy(true);
  }

  boardsStore.create();

  issueBoardsApp = new Vue({
    el: $boardApp,
    components: {
      Board,
      BoardSidebar,
      BoardAddIssuesModal,
    },
    data: {
      state: boardsStore.state,
      loading: true,
      boardsEndpoint: $boardApp.dataset.boardsEndpoint,
      recentBoardsEndpoint: $boardApp.dataset.recentBoardsEndpoint,
      listsEndpoint: $boardApp.dataset.listsEndpoint,
      boardId: $boardApp.dataset.boardId,
      disabled: parseBoolean($boardApp.dataset.disabled),
      issueLinkBase: $boardApp.dataset.issueLinkBase,
      rootPath: $boardApp.dataset.rootPath,
      bulkUpdatePath: $boardApp.dataset.bulkUpdatePath,
      detailIssue: boardsStore.detail,
      defaultAvatar: $boardApp.dataset.defaultAvatar,
    },
    computed: {
      detailIssueVisible() {
        return Object.keys(this.detailIssue.issue).length;
      },
    },
    created() {
      gl.boardService = new BoardService({
        boardsEndpoint: this.boardsEndpoint,
        recentBoardsEndpoint: this.recentBoardsEndpoint,
        listsEndpoint: this.listsEndpoint,
        bulkUpdatePath: this.bulkUpdatePath,
        boardId: this.boardId,
      });
      boardsStore.rootPath = this.boardsEndpoint;

      eventHub.$on('updateTokens', this.updateTokens);
      eventHub.$on('newDetailIssue', this.updateDetailIssue);
      eventHub.$on('clearDetailIssue', this.clearDetailIssue);
      sidebarEventHub.$on('toggleSubscription', this.toggleSubscription);
    },
    beforeDestroy() {
      eventHub.$off('updateTokens', this.updateTokens);
      eventHub.$off('newDetailIssue', this.updateDetailIssue);
      eventHub.$off('clearDetailIssue', this.clearDetailIssue);
      sidebarEventHub.$off('toggleSubscription', this.toggleSubscription);
    },
    mounted() {
      this.filterManager = new FilteredSearchBoards(boardsStore.filter, true, boardsStore.cantEdit);
      this.filterManager.setup();

      boardsStore.disabled = this.disabled;
      gl.boardService
        .all()
        .then(res => res.data)
        .then(lists => {
          lists.forEach(listObj => {
            let { position } = listObj;
            if (listObj.list_type === 'closed') {
              position = Infinity;
            } else if (listObj.list_type === 'backlog') {
              position = -1;
            }

            boardsStore.addList(
              {
                ...listObj,
                position,
              },
              this.defaultAvatar,
            );
          });

          boardsStore.addBlankState();
          this.loading = false;
        })
        .catch(() => {
          Flash(__('An error occurred while fetching the board lists. Please try again.'));
        });
    },
    methods: {
      updateTokens() {
        this.filterManager.updateTokens();
      },
      updateDetailIssue(newIssue) {
        const { sidebarInfoEndpoint } = newIssue;
        if (sidebarInfoEndpoint && newIssue.subscribed === undefined) {
          newIssue.setFetchingState('subscriptions', true);
          BoardService.getIssueInfo(sidebarInfoEndpoint)
            .then(res => res.data)
            .then(data => {
              const {
                subscribed,
                totalTimeSpent,
                timeEstimate,
                humanTimeEstimate,
                humanTotalTimeSpent,
                weight,
                epic,
              } = convertObjectPropsToCamelCase(data);

              newIssue.setFetchingState('subscriptions', false);
              newIssue.updateData({
                humanTimeSpent: humanTotalTimeSpent,
                timeSpent: totalTimeSpent,
                humanTimeEstimate,
                timeEstimate,
                subscribed,
                weight,
                epic,
              });
            })
            .catch(() => {
              newIssue.setFetchingState('subscriptions', false);
              Flash(__('An error occurred while fetching sidebar data'));
            });
        }

        boardsStore.setIssueDetail(newIssue);
      },
      clearDetailIssue() {
        boardsStore.clearDetailIssue();
      },
      toggleSubscription(id) {
        const { issue } = boardsStore.detail;
        if (issue.id === id && issue.toggleSubscriptionEndpoint) {
          issue.setFetchingState('subscriptions', true);
          BoardService.toggleIssueSubscription(issue.toggleSubscriptionEndpoint)
            .then(() => {
              issue.setFetchingState('subscriptions', false);
              issue.updateData({
                subscribed: !issue.subscribed,
              });
            })
            .catch(() => {
              issue.setFetchingState('subscriptions', false);
              Flash(__('An error occurred when toggling the notification subscription'));
            });
        }
      },
    },
  });

  // eslint-disable-next-line no-new
  new Vue({
    el: document.getElementById('js-add-list'),
    data: {
      filters: boardsStore.state.filters,
    },
    mounted() {
      initNewListDropdown();
    },
  });

  const issueBoardsModal = document.getElementById('js-add-issues-btn');

  if (issueBoardsModal) {
    // eslint-disable-next-line no-new
    new Vue({
      el: issueBoardsModal,
      mixins: [modalMixin],
      data() {
        return {
          modal: ModalStore.store,
          store: boardsStore.state,
          canAdminList: this.$options.el.hasAttribute('data-can-admin-list'),
        };
      },
      computed: {
        disabled() {
          if (!this.store) {
            return true;
          }
          return !this.store.lists.filter(list => !list.preset).length;
        },
        tooltipTitle() {
          if (this.disabled) {
            return __('Please add a list to your board first');
          }

          return '';
        },
      },
      watch: {
        disabled() {
          this.updateTooltip();
        },
      },
      mounted() {
        this.updateTooltip();
      },
      methods: {
        updateTooltip() {
          const $tooltip = $(this.$refs.addIssuesButton);

          this.$nextTick(() => {
            if (this.disabled) {
              $tooltip.tooltip();
            } else {
              $tooltip.tooltip('dispose');
            }
          });
        },
        openModal() {
          if (!this.disabled) {
            this.toggleModal(true);
          }
        },
      },
      template: `
        <div class="board-extra-actions">
          <button
            class="btn btn-success prepend-left-10"
            type="button"
            data-placement="bottom"
            ref="addIssuesButton"
            :class="{ 'disabled': disabled }"
            :title="tooltipTitle"
            :aria-disabled="disabled"
            v-if="canAdminList"
            @click="openModal">
            Add issues
          </button>
        </div>
      `,
    });
  }
};
