import Vue from 'vue';
import * as types from './mutation_types';
import { logLinesParser, updateIncrementalJobLog } from './utils';

export default {
  [types.SET_JOB_ENDPOINT](state, endpoint) {
    state.jobEndpoint = endpoint;
  },

  [types.SET_JOB_LOG_OPTIONS](state, options = {}) {
    state.jobLogEndpoint = options.pagePath;
    state.jobLogState = options.logState;
  },

  [types.HIDE_SIDEBAR](state) {
    state.isSidebarOpen = false;
  },
  [types.SHOW_SIDEBAR](state) {
    state.isSidebarOpen = true;
  },

  [types.RECEIVE_JOB_LOG_SUCCESS](state, log = {}) {
    if (log.state) {
      state.jobLogState = log.state;
    }

    if (log.append) {
      state.jobLog = log.lines ? updateIncrementalJobLog(log.lines, state.jobLog) : state.jobLog;

      state.jobLogSize += log.size;
    } else {
      // When the job still does not have a log
      // the job log response will not have a defined
      // html or size. We keep the old value otherwise these
      // will be set to `null`

      state.jobLog = log.lines ? logLinesParser(log.lines) : state.jobLog;

      state.jobLogSize = log.size || state.jobLogSize;
    }

    if (state.jobLogSize < log.total) {
      state.isJobLogSizeVisible = true;
    } else {
      state.isJobLogSizeVisible = false;
    }

    state.isJobLogComplete = log.complete || state.isJobLogComplete;
  },

  [types.SET_JOB_LOG_TIMEOUT](state, id) {
    state.jobLogTimeout = id;
  },

  /**
   * Will remove loading animation
   */
  [types.STOP_POLLING_JOB_LOG](state) {
    state.isJobLogComplete = true;
  },

  /**
   * Instead of filtering the array of lines to find the one that must be updated
   * we use Vue.set to make this process more performant
   *
   * https://vuex.vuejs.org/guide/mutations.html#mutations-follow-vue-s-reactivity-rules
   * @param {Object} state
   * @param {Object} section
   */
  [types.TOGGLE_COLLAPSIBLE_LINE](state, section) {
    Vue.set(section, 'isClosed', !section.isClosed);
  },

  [types.REQUEST_JOB](state) {
    state.isLoading = true;
  },
  [types.RECEIVE_JOB_SUCCESS](state, job) {
    state.hasError = false;
    state.isLoading = false;
    state.job = job;

    state.stages =
      job.pipeline && job.pipeline.details && job.pipeline.details.stages
        ? job.pipeline.details.stages
        : [];

    /**
     * We only update it on the first request
     * The dropdown can be changed by the user
     * after the first request,
     * and we do not want to hijack that
     */
    if (state.selectedStage === '' && job.stage) {
      state.selectedStage = job.stage;
    }
  },
  [types.RECEIVE_JOB_ERROR](state) {
    state.isLoading = false;
    state.job = {};
    state.hasError = true;
  },

  [types.ENABLE_SCROLL_TOP](state) {
    state.isScrollTopDisabled = false;
  },
  [types.DISABLE_SCROLL_TOP](state) {
    state.isScrollTopDisabled = true;
  },
  [types.ENABLE_SCROLL_BOTTOM](state) {
    state.isScrollBottomDisabled = false;
  },
  [types.DISABLE_SCROLL_BOTTOM](state) {
    state.isScrollBottomDisabled = true;
  },
  [types.TOGGLE_SCROLL_ANIMATION](state, toggle) {
    state.isScrollingDown = toggle;
  },

  [types.TOGGLE_IS_SCROLL_IN_BOTTOM_BEFORE_UPDATING_JOB_LOG](state, toggle) {
    state.isScrolledToBottomBeforeReceivingJobLog = toggle;
  },

  [types.REQUEST_JOBS_FOR_STAGE](state, stage = {}) {
    state.isLoadingJobs = true;
    state.selectedStage = stage.name;
  },
  [types.RECEIVE_JOBS_FOR_STAGE_SUCCESS](state, jobs) {
    state.isLoadingJobs = false;
    state.jobs = jobs;
  },
  [types.RECEIVE_JOBS_FOR_STAGE_ERROR](state) {
    state.isLoadingJobs = false;
    state.jobs = [];
  },
};
