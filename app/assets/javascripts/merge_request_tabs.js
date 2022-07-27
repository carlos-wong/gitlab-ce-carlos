/* eslint-disable no-new, class-methods-use-this */
import $ from 'jquery';
import Vue from 'vue';
import { getCookie, isMetaClick, parseBoolean, scrollToElement } from '~/lib/utils/common_utils';
import { parseUrlPathname } from '~/lib/utils/url_utility';
import createEventHub from '~/helpers/event_hub_factory';
import BlobForkSuggestion from './blob/blob_fork_suggestion';
import Diff from './diff';
import createFlash from './flash';
import { initDiffStatsDropdown } from './init_diff_stats_dropdown';
import axios from './lib/utils/axios_utils';

import { localTimeAgo } from './lib/utils/datetime_utility';
import { isInVueNoteablePage } from './lib/utils/dom_utils';
import { __ } from './locale';
import syntaxHighlight from './syntax_highlight';

// MergeRequestTabs
//
// Handles persisting and restoring the current tab selection and lazily-loading
// content on the MergeRequests#show page.
//
// ### Example Markup
//
//   <ul class="nav-links merge-request-tabs">
//     <li class="notes-tab active">
//       <a data-action="notes" data-target="#notes" data-toggle="tab" href="/foo/bar/-/merge_requests/1">
//         Discussion
//       </a>
//     </li>
//     <li class="commits-tab">
//       <a data-action="commits" data-target="#commits" data-toggle="tab" href="/foo/bar/-/merge_requests/1/commits">
//         Commits
//       </a>
//     </li>
//     <li class="diffs-tab">
//       <a data-action="diffs" data-target="#diffs" data-toggle="tab" href="/foo/bar/-/merge_requests/1/diffs">
//         Diffs
//       </a>
//     </li>
//   </ul>
//
//   <div class="tab-content">
//     <div class="notes tab-pane active" id="notes">
//       Notes Content
//     </div>
//     <div class="commits tab-pane" id="commits">
//       Commits Content
//     </div>
//     <div class="diffs tab-pane" id="diffs">
//       Diffs Content
//     </div>
//   </div>
//
//   <div class="mr-loading-status">
//     <div class="loading">
//       Loading Animation
//     </div>
//   </div>
//

// <100ms is typically indistinguishable from "instant" for users, but allows for re-rendering
const FAST_DELAY_FOR_RERENDER = 75;
// Store the `location` object, allowing for easier stubbing in tests
let { location } = window;

function scrollToContainer(container) {
  if (location.hash) {
    const $el = $(`${container} ${location.hash}:not(.match)`);

    if ($el.length) {
      scrollToElement($el[0]);
    }
  }
}

function computeTopOffset(tabs) {
  const navbar = document.querySelector('.navbar-gitlab');
  const peek = document.getElementById('js-peek');
  let stickyTop;

  stickyTop = navbar ? navbar.offsetHeight : 0;
  stickyTop = peek ? stickyTop + peek.offsetHeight : stickyTop;
  stickyTop = tabs ? stickyTop + tabs.offsetHeight : stickyTop;

  return stickyTop;
}

function mountPipelines() {
  const pipelineTableViewEl = document.querySelector('#commit-pipeline-table-view');
  const { mrWidgetData } = gl;
  const table = new Vue({
    components: {
      CommitPipelinesTable: () => import('~/commit/pipelines/pipelines_table.vue'),
    },
    provide: {
      artifactsEndpoint: pipelineTableViewEl.dataset.artifactsEndpoint,
      artifactsEndpointPlaceholder: pipelineTableViewEl.dataset.artifactsEndpointPlaceholder,
      targetProjectFullPath: mrWidgetData?.target_project_full_path || '',
    },
    render(createElement) {
      return createElement('commit-pipelines-table', {
        props: {
          endpoint: pipelineTableViewEl.dataset.endpoint,
          emptyStateSvgPath: pipelineTableViewEl.dataset.emptyStateSvgPath,
          errorStateSvgPath: pipelineTableViewEl.dataset.errorStateSvgPath,
          canCreatePipelineInTargetProject: Boolean(
            mrWidgetData?.can_create_pipeline_in_target_project,
          ),
          sourceProjectFullPath: mrWidgetData?.source_project_full_path || '',
          targetProjectFullPath: mrWidgetData?.target_project_full_path || '',
          projectId: pipelineTableViewEl.dataset.projectId,
          mergeRequestId: mrWidgetData ? mrWidgetData.iid : null,
        },
      });
    },
  }).$mount();

  // $mount(el) replaces the el with the new rendered component. We need it in order to mount
  // it everytime this tab is clicked - https://vuejs.org/v2/api/#vm-mount
  pipelineTableViewEl.appendChild(table.$el);

  return table;
}

function destroyPipelines(app) {
  if (app && app.$destroy) {
    app.$destroy();

    document.querySelector('#commit-pipeline-table-view').innerHTML = '';
  }

  return null;
}

function loadDiffs({ url, sticky }) {
  return axios.get(`${url}.json${location.search}`).then(({ data }) => {
    const $container = $('#diffs');
    $container.html(data.html);
    initDiffStatsDropdown(sticky);

    localTimeAgo(document.querySelectorAll('#diffs .js-timeago'));
    syntaxHighlight($('#diffs .js-syntax-highlight'));

    new Diff();
    scrollToContainer('#diffs');

    $('.diff-file').each((i, el) => {
      new BlobForkSuggestion({
        openButtons: $(el).find('.js-edit-blob-link-fork-toggler'),
        forkButtons: $(el).find('.js-fork-suggestion-button'),
        cancelButtons: $(el).find('.js-cancel-fork-suggestion-button'),
        suggestionSections: $(el).find('.js-file-fork-suggestion-section'),
        actionTextPieces: $(el).find('.js-file-fork-suggestion-section-action'),
      }).init();
    });
  });
}

function toggleLoader(state) {
  $('.mr-loading-status .loading').toggleClass('hide', !state);
}

export default class MergeRequestTabs {
  constructor({ action, setUrl, stubLocation } = {}) {
    this.mergeRequestTabs = document.querySelector('.merge-request-tabs-container');
    this.mergeRequestTabsAll =
      this.mergeRequestTabs && this.mergeRequestTabs.querySelectorAll
        ? this.mergeRequestTabs.querySelectorAll('.merge-request-tabs li')
        : null;
    this.mergeRequestTabPanes = document.querySelector('#diff-notes-app');
    this.mergeRequestTabPanesAll =
      this.mergeRequestTabPanes && this.mergeRequestTabPanes.querySelectorAll
        ? this.mergeRequestTabPanes.querySelectorAll('.tab-pane')
        : null;
    this.navbar = document.querySelector('.navbar-gitlab');
    this.peek = document.getElementById('js-peek');
    this.sidebar = document.querySelector('.js-right-sidebar');
    this.pageLayout = document.querySelector('.layout-page');
    this.expandSidebar = document.querySelectorAll('.js-expand-sidebar, .js-sidebar-toggle');
    this.paddingTop = 16;

    this.scrollPositions = {};

    this.commitsTab = document.querySelector('.tab-content .commits.tab-pane');

    this.currentTab = null;
    this.diffsLoaded = false;
    this.pipelinesLoaded = false;
    this.commitsLoaded = false;
    this.fixedLayoutPref = null;
    this.eventHub = createEventHub();

    this.setUrl = setUrl !== undefined ? setUrl : true;
    this.setCurrentAction = this.setCurrentAction.bind(this);
    this.tabShown = this.tabShown.bind(this);
    this.clickTab = this.clickTab.bind(this);

    if (stubLocation) {
      location = stubLocation;
    }

    this.bindEvents();
    this.mergeRequestTabs?.querySelector(`a[data-action='${action}']`)?.click?.();
  }

  bindEvents() {
    $('.merge-request-tabs a[data-toggle="tabvue"]').on('click', this.clickTab);
    window.addEventListener('popstate', (event) => {
      if (event.state && event.state.action) {
        this.tabShown(event.state.action, event.target.location);
        this.currentAction = event.state.action;
        this.eventHub.$emit('MergeRequestTabChange', this.getCurrentAction());
      }
    });
  }

  // Used in tests
  unbindEvents() {
    $('.merge-request-tabs a[data-toggle="tabvue"]').off('click', this.clickTab);
  }

  storeScroll() {
    if (this.currentTab) {
      this.scrollPositions[this.currentTab] = document.documentElement.scrollTop;
    }
  }
  recallScroll(action) {
    const storedPosition = this.scrollPositions[action];

    setTimeout(() => {
      window.scrollTo({
        top: storedPosition && storedPosition > 0 ? storedPosition : 0,
        left: 0,
        behavior: 'auto',
      });
    }, FAST_DELAY_FOR_RERENDER);
  }

  clickTab(e) {
    if (e.currentTarget) {
      e.stopImmediatePropagation();
      e.preventDefault();

      this.storeScroll();

      const { action } = e.currentTarget.dataset || {};

      if (isMetaClick(e)) {
        const targetLink = e.currentTarget.getAttribute('href');
        window.open(targetLink, '_blank');
      } else if (action) {
        const href = e.currentTarget.getAttribute('href');
        this.tabShown(action, href);

        if (this.setUrl) {
          this.setCurrentAction(action);
        }
      }
    }
  }

  tabShown(action, href) {
    if (action !== this.currentTab && this.mergeRequestTabs) {
      this.currentTab = action;

      if (this.mergeRequestTabPanesAll) {
        this.mergeRequestTabPanesAll.forEach((el) => {
          const tabPane = el;
          tabPane.style.display = 'none';
        });
      }

      if (this.mergeRequestTabsAll) {
        this.mergeRequestTabsAll.forEach((el) => {
          el.classList.remove('active');
        });
      }

      const tabPane = this.mergeRequestTabPanes.querySelector(`#${action}`);
      if (tabPane) tabPane.style.display = 'block';
      const tab = this.mergeRequestTabs.querySelector(`.${action}-tab`);
      if (tab) tab.classList.add('active');

      if (window.gon?.features?.movedMrSidebar) {
        this.expandSidebar?.forEach((el) =>
          el.classList.toggle('gl-display-none!', action !== 'show'),
        );
      }

      if (action === 'commits') {
        this.loadCommits(href);
        // this.hideSidebar();
        this.resetViewContainer();
        this.commitPipelinesTable = destroyPipelines(this.commitPipelinesTable);
      } else if (action === 'new') {
        this.expandView();
        this.resetViewContainer();
        this.commitPipelinesTable = destroyPipelines(this.commitPipelinesTable);
      } else if (this.isDiffAction(action)) {
        if (!isInVueNoteablePage()) {
          /*
            for pages where we have not yet converted to the new vue
            implementation we load the diff tab content the old way,
            inserting html rendered by the backend.

            in practice, this only occurs when comparing commits in
            the new merge request form page.
          */
          this.loadDiff(href);
        }
        // this.hideSidebar();
        this.expandViewContainer();
        this.commitPipelinesTable = destroyPipelines(this.commitPipelinesTable);
        this.commitsTab.classList.remove('active');
      } else if (action === 'pipelines') {
        // this.hideSidebar();
        this.resetViewContainer();
        this.mountPipelinesView();
      } else {
        const notesTab = this.mergeRequestTabs.querySelector('.notes-tab');
        const notesPane = this.mergeRequestTabPanes.querySelector('#notes');
        if (notesPane) {
          notesPane.style.display = 'block';
        }
        if (notesTab) {
          notesTab.classList.add('active');
        }

        // this.showSidebar();
        this.resetViewContainer();
        this.commitPipelinesTable = destroyPipelines(this.commitPipelinesTable);
      }

      $('.detail-page-description').renderGFM();

      this.recallScroll(action);
    } else if (action === this.currentAction) {
      // ContentTop is used to handle anything at the top of the page before the main content
      const mainContentContainer = document.querySelector('.content-wrapper');
      const tabContentContainer = document.querySelector('.tab-content');

      if (mainContentContainer && tabContentContainer) {
        const mainContentTop = mainContentContainer.getBoundingClientRect().top;
        const tabContentTop = tabContentContainer.getBoundingClientRect().top;

        // 51px is the height of the navbar buttons, e.g. `Discussion | Commits | Changes`
        const scrollDestination = tabContentTop - mainContentTop - 51;

        // scrollBehavior is only available in browsers that support scrollToOptions
        if ('scrollBehavior' in document.documentElement.style) {
          window.scrollTo({
            top: scrollDestination,
            behavior: 'smooth',
          });
        } else {
          window.scrollTo(0, scrollDestination);
        }
      }
    }

    this.eventHub.$emit('MergeRequestTabChange', action);
  }

  // Replaces the current merge request-specific action in the URL with a new one
  //
  // If the action is "notes", the URL is reset to the standard
  // `MergeRequests#show` route.
  //
  // Examples:
  //
  //   location.pathname # => "/namespace/project/-/merge_requests/1"
  //   setCurrentAction('diffs')
  //   location.pathname # => "/namespace/project/-/merge_requests/1/diffs"
  //
  //   location.pathname # => "/namespace/project/-/merge_requests/1/diffs"
  //   setCurrentAction('show')
  //   location.pathname # => "/namespace/project/-/merge_requests/1"
  //
  //   location.pathname # => "/namespace/project/-/merge_requests/1/diffs"
  //   setCurrentAction('commits')
  //   location.pathname # => "/namespace/project/-/merge_requests/1/commits"
  //
  // Returns the new URL String
  setCurrentAction(action) {
    this.currentAction = action;

    // Remove a trailing '/commits' '/diffs' '/pipelines'
    let newState = location.pathname.replace(/\/(commits|diffs|pipelines)(\.html)?\/?$/, '');

    // Append the new action if we're on a tab other than 'notes'
    if (this.currentAction !== 'show' && this.currentAction !== 'new') {
      newState += `/${this.currentAction}`;
    }

    // Ensure parameters and hash come along for the ride
    newState += location.search + location.hash;

    if (window.history.state && window.history.state.url && window.location.pathname !== newState) {
      window.history.pushState(
        {
          url: newState,
          action: this.currentAction,
        },
        document.title,
        newState,
      );
    } else {
      window.history.replaceState(
        {
          url: window.location.href,
          action,
        },
        document.title,
        window.location.href,
      );
    }

    return newState;
  }

  getCurrentAction() {
    return this.currentAction;
  }

  loadCommits(source) {
    if (this.commitsLoaded) {
      return;
    }

    toggleLoader(true);

    axios
      .get(`${source}.json`)
      .then(({ data }) => {
        const commitsDiv = document.querySelector('div#commits');
        commitsDiv.innerHTML = data.html;
        localTimeAgo(commitsDiv.querySelectorAll('.js-timeago'));
        this.commitsLoaded = true;
        scrollToContainer('#commits');

        toggleLoader(false);

        return import('./add_context_commits_modal');
      })
      .then((m) => m.default())
      .catch(() => {
        toggleLoader(false);
        createFlash({
          message: __('An error occurred while fetching this tab.'),
        });
      });
  }

  mountPipelinesView() {
    this.commitPipelinesTable = mountPipelines();
  }

  // load the diff tab content from the backend
  loadDiff(source) {
    if (this.diffsLoaded) {
      document.dispatchEvent(new CustomEvent('scroll'));
      return;
    }

    toggleLoader(true);

    loadDiffs({
      // We extract pathname for the current Changes tab anchor href
      // some pages like MergeRequestsController#new has query parameters on that anchor
      url: parseUrlPathname(source),
      sticky: computeTopOffset(this.mergeRequestTabs),
    })
      .then(() => {
        if (this.isDiffAction(this.currentAction)) {
          this.expandViewContainer();
        }

        this.diffsLoaded = true;
      })
      .catch(() => {
        createFlash({
          message: __('An error occurred while fetching this tab.'),
        });
      })
      .finally(() => {
        toggleLoader(false);
      });
  }

  diffViewType() {
    return $('.js-diff-view-buttons button.active').data('viewType');
  }

  isDiffAction(action) {
    return action === 'diffs' || action === 'new/diffs';
  }

  expandViewContainer(removeLimited = true) {
    const $wrapper = $('.content-wrapper .container-fluid').not('.breadcrumbs');
    if (this.fixedLayoutPref === null) {
      this.fixedLayoutPref = $wrapper.hasClass('container-limited');
    }
    if (this.diffViewType() === 'parallel' || removeLimited) {
      $wrapper.removeClass('container-limited');
    } else {
      $wrapper.toggleClass('container-limited', this.fixedLayoutPref);
    }
  }

  resetViewContainer() {
    if (this.fixedLayoutPref !== null) {
      $('.content-wrapper .container-fluid').toggleClass('container-limited', this.fixedLayoutPref);
    }
  }

  // Expand the issuable sidebar unless the user explicitly collapsed it
  expandView() {
    if (parseBoolean(getCookie('collapsed_gutter'))) {
      return;
    }
    const $gutterBtn = $('.js-sidebar-toggle');
    const $collapseSvg = $gutterBtn.find('.js-sidebar-collapse');

    // Wait until listeners are set
    setTimeout(() => {
      // Only when sidebar is collapsed
      if ($collapseSvg.length && !$collapseSvg.hasClass('hidden')) {
        $gutterBtn.trigger('click', [true]);
      }
    }, 0);
  }

  hideSidebar() {
    if (!isInVueNoteablePage() || this.cachedPageLayoutClasses) return;

    this.cachedPageLayoutClasses = this.pageLayout.className;
    this.pageLayout.classList.remove(
      'right-sidebar-collapsed',
      'right-sidebar-expanded',
      'page-with-icon-sidebar',
    );
    this.sidebar.style.width = '0px';
  }

  showSidebar() {
    if (!isInVueNoteablePage() || !this.cachedPageLayoutClasses) return;

    this.pageLayout.className = this.cachedPageLayoutClasses;
    this.sidebar.style.width = '';
    delete this.cachedPageLayoutClasses;
  }
}
