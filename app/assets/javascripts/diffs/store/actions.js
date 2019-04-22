import Vue from 'vue';
import axios from '~/lib/utils/axios_utils';
import Cookies from 'js-cookie';
import createFlash from '~/flash';
import { s__ } from '~/locale';
import { handleLocationHash, historyPushState, scrollToElement } from '~/lib/utils/common_utils';
import { mergeUrlParams, getLocationHash } from '~/lib/utils/url_utility';
import TreeWorker from '../workers/tree_worker';
import eventHub from '../../notes/event_hub';
import { getDiffPositionByLineCode, getNoteFormData } from './utils';
import * as types from './mutation_types';
import {
  PARALLEL_DIFF_VIEW_TYPE,
  INLINE_DIFF_VIEW_TYPE,
  DIFF_VIEW_COOKIE_NAME,
  MR_TREE_SHOW_KEY,
  TREE_LIST_STORAGE_KEY,
  WHITESPACE_STORAGE_KEY,
  TREE_LIST_WIDTH_STORAGE_KEY,
} from '../constants';
import { diffViewerModes } from '~/ide/constants';

export const setBaseConfig = ({ commit }, options) => {
  const { endpoint, projectPath } = options;
  commit(types.SET_BASE_CONFIG, { endpoint, projectPath });
};

export const fetchDiffFiles = ({ state, commit }) => {
  const worker = new TreeWorker();

  commit(types.SET_LOADING, true);

  worker.addEventListener('message', ({ data }) => {
    commit(types.SET_TREE_DATA, data);

    worker.terminate();
  });

  return axios
    .get(state.endpoint, { params: { w: state.showWhitespace ? null : '1' } })
    .then(res => {
      commit(types.SET_LOADING, false);
      commit(types.SET_MERGE_REQUEST_DIFFS, res.data.merge_request_diffs || []);
      commit(types.SET_DIFF_DATA, res.data);

      worker.postMessage(state.diffFiles);

      return Vue.nextTick();
    })
    .then(handleLocationHash)
    .catch(() => worker.terminate());
};

export const setHighlightedRow = ({ commit }, lineCode) => {
  const fileHash = lineCode.split('_')[0];
  commit(types.SET_HIGHLIGHTED_ROW, lineCode);
  commit(types.UPDATE_CURRENT_DIFF_FILE_ID, fileHash);
};

// This is adding line discussions to the actual lines in the diff tree
// once for parallel and once for inline mode
export const assignDiscussionsToDiff = (
  { commit, state, rootState },
  discussions = rootState.notes.discussions,
) => {
  const diffPositionByLineCode = getDiffPositionByLineCode(state.diffFiles);

  discussions
    .filter(discussion => discussion.diff_discussion)
    .forEach(discussion => {
      commit(types.SET_LINE_DISCUSSIONS_FOR_FILE, {
        discussion,
        diffPositionByLineCode,
      });
    });

  Vue.nextTick(() => {
    eventHub.$emit('scrollToDiscussion');
  });
};

export const removeDiscussionsFromDiff = ({ commit }, removeDiscussion) => {
  const { file_hash, line_code, id } = removeDiscussion;
  commit(types.REMOVE_LINE_DISCUSSIONS_FOR_FILE, { fileHash: file_hash, lineCode: line_code, id });
};

export const renderFileForDiscussionId = ({ commit, rootState, state }, discussionId) => {
  const discussion = rootState.notes.discussions.find(d => d.id === discussionId);

  if (discussion) {
    const file = state.diffFiles.find(f => f.file_hash === discussion.diff_file.file_hash);

    if (file) {
      if (!file.renderIt) {
        commit(types.RENDER_FILE, file);
      }

      if (file.viewer.collapsed) {
        eventHub.$emit(`loadCollapsedDiff/${file.file_hash}`);
        scrollToElement(document.getElementById(file.file_hash));
      } else {
        eventHub.$emit('scrollToDiscussion');
      }
    }
  }
};

export const startRenderDiffsQueue = ({ state, commit }) => {
  const checkItem = () =>
    new Promise(resolve => {
      const nextFile = state.diffFiles.find(
        file =>
          !file.renderIt && (!file.viewer.collapsed || !file.viewer.name === diffViewerModes.text),
      );

      if (nextFile) {
        requestAnimationFrame(() => {
          commit(types.RENDER_FILE, nextFile);
        });
        requestIdleCallback(
          () => {
            checkItem()
              .then(resolve)
              .catch(() => {});
          },
          { timeout: 1000 },
        );
      } else {
        resolve();
      }
    });

  return checkItem();
};

export const setRenderIt = ({ commit }, file) => commit(types.RENDER_FILE, file);

export const setInlineDiffViewType = ({ commit }) => {
  commit(types.SET_DIFF_VIEW_TYPE, INLINE_DIFF_VIEW_TYPE);

  Cookies.set(DIFF_VIEW_COOKIE_NAME, INLINE_DIFF_VIEW_TYPE);
  const url = mergeUrlParams({ view: INLINE_DIFF_VIEW_TYPE }, window.location.href);
  historyPushState(url);
};

export const setParallelDiffViewType = ({ commit }) => {
  commit(types.SET_DIFF_VIEW_TYPE, PARALLEL_DIFF_VIEW_TYPE);

  Cookies.set(DIFF_VIEW_COOKIE_NAME, PARALLEL_DIFF_VIEW_TYPE);
  const url = mergeUrlParams({ view: PARALLEL_DIFF_VIEW_TYPE }, window.location.href);
  historyPushState(url);
};

export const showCommentForm = ({ commit }, { lineCode, fileHash }) => {
  commit(types.TOGGLE_LINE_HAS_FORM, { lineCode, fileHash, hasForm: true });
};

export const cancelCommentForm = ({ commit }, { lineCode, fileHash }) => {
  commit(types.TOGGLE_LINE_HAS_FORM, { lineCode, fileHash, hasForm: false });
};

export const loadMoreLines = ({ commit }, options) => {
  const { endpoint, params, lineNumbers, fileHash } = options;

  params.from_merge_request = true;

  return axios.get(endpoint, { params }).then(res => {
    const contextLines = res.data || [];

    commit(types.ADD_CONTEXT_LINES, {
      lineNumbers,
      contextLines,
      params,
      fileHash,
    });
  });
};

export const scrollToLineIfNeededInline = (_, line) => {
  const hash = getLocationHash();

  if (hash && line.line_code === hash) {
    handleLocationHash();
  }
};

export const scrollToLineIfNeededParallel = (_, line) => {
  const hash = getLocationHash();

  if (
    hash &&
    ((line.left && line.left.line_code === hash) || (line.right && line.right.line_code === hash))
  ) {
    handleLocationHash();
  }
};

export const loadCollapsedDiff = ({ commit, getters }, file) =>
  axios
    .get(file.load_collapsed_diff_url, {
      params: {
        commit_id: getters.commitId,
      },
    })
    .then(res => {
      commit(types.ADD_COLLAPSED_DIFFS, {
        file,
        data: res.data,
      });
    });

export const expandAllFiles = ({ commit }) => {
  commit(types.EXPAND_ALL_FILES);
};

/**
 * Toggles the file discussions after user clicked on the toggle discussions button.
 *
 * Gets the discussions for the provided diff.
 *
 * If all discussions are expanded, it will collapse all of them
 * If all discussions are collapsed, it will expand all of them
 * If some discussions are open and others closed, it will expand the closed ones.
 *
 * @param {Object} diff
 */
export const toggleFileDiscussions = ({ getters, dispatch }, diff) => {
  const discussions = getters.getDiffFileDiscussions(diff);
  const shouldCloseAll = getters.diffHasAllExpandedDiscussions(diff);
  const shouldExpandAll = getters.diffHasAllCollapsedDiscussions(diff);

  discussions.forEach(discussion => {
    const data = { discussionId: discussion.id };

    if (shouldCloseAll) {
      dispatch('collapseDiscussion', data, { root: true });
    } else if (shouldExpandAll || (!shouldCloseAll && !shouldExpandAll && !discussion.expanded)) {
      dispatch('expandDiscussion', data, { root: true });
    }
  });
};

export const saveDiffDiscussion = ({ state, dispatch }, { note, formData }) => {
  const postData = getNoteFormData({
    commit: state.commit,
    note,
    ...formData,
  });

  return dispatch('saveNote', postData, { root: true })
    .then(result => dispatch('updateDiscussion', result.discussion, { root: true }))
    .then(discussion => dispatch('assignDiscussionsToDiff', [discussion]))
    .then(() => dispatch('updateResolvableDiscussonsCounts', null, { root: true }))
    .then(() => dispatch('closeDiffFileCommentForm', formData.diffFile.file_hash))
    .catch(() => createFlash(s__('MergeRequests|Saving the comment failed')));
};

export const toggleTreeOpen = ({ commit }, path) => {
  commit(types.TOGGLE_FOLDER_OPEN, path);
};

export const scrollToFile = ({ state, commit }, path) => {
  const { fileHash } = state.treeEntries[path];
  document.location.hash = fileHash;

  commit(types.UPDATE_CURRENT_DIFF_FILE_ID, fileHash);
};

export const toggleShowTreeList = ({ commit, state }, saving = true) => {
  commit(types.TOGGLE_SHOW_TREE_LIST);

  if (saving) {
    localStorage.setItem(MR_TREE_SHOW_KEY, state.showTreeList);
  }
};

export const openDiffFileCommentForm = ({ commit, getters }, formData) => {
  const form = getters.getCommentFormForDiffFile(formData.fileHash);

  if (form) {
    commit(types.UPDATE_DIFF_FILE_COMMENT_FORM, formData);
  } else {
    commit(types.OPEN_DIFF_FILE_COMMENT_FORM, formData);
  }
};

export const closeDiffFileCommentForm = ({ commit }, fileHash) => {
  commit(types.CLOSE_DIFF_FILE_COMMENT_FORM, fileHash);
};

export const setRenderTreeList = ({ commit }, renderTreeList) => {
  commit(types.SET_RENDER_TREE_LIST, renderTreeList);

  localStorage.setItem(TREE_LIST_STORAGE_KEY, renderTreeList);
};

export const setShowWhitespace = ({ commit }, { showWhitespace, pushState = false }) => {
  commit(types.SET_SHOW_WHITESPACE, showWhitespace);

  localStorage.setItem(WHITESPACE_STORAGE_KEY, showWhitespace);

  if (pushState) {
    historyPushState(showWhitespace ? '?w=0' : '?w=1');
  }
};

export const toggleFileFinder = ({ commit }, visible) => {
  commit(types.TOGGLE_FILE_FINDER_VISIBLE, visible);
};

export const cacheTreeListWidth = (_, size) => {
  localStorage.setItem(TREE_LIST_WIDTH_STORAGE_KEY, size);
};

export const requestFullDiff = ({ commit }, filePath) => commit(types.REQUEST_FULL_DIFF, filePath);
export const receiveFullDiffSucess = ({ commit }, { filePath, data }) =>
  commit(types.RECEIVE_FULL_DIFF_SUCCESS, { filePath, data });
export const receiveFullDiffError = ({ commit }, filePath) => {
  commit(types.RECEIVE_FULL_DIFF_ERROR, filePath);
  createFlash(s__('MergeRequest|Error loading full diff. Please try again.'));
};

export const fetchFullDiff = ({ dispatch }, file) =>
  axios
    .get(file.context_lines_path, {
      params: {
        full: true,
        from_merge_request: true,
      },
    })
    .then(({ data }) => dispatch('receiveFullDiffSucess', { filePath: file.file_path, data }))
    .then(() => scrollToElement(`#${file.file_hash}`))
    .catch(() => dispatch('receiveFullDiffError', file.file_path));

export const toggleFullDiff = ({ dispatch, getters, state }, filePath) => {
  const file = state.diffFiles.find(f => f.file_path === filePath);

  dispatch('requestFullDiff', filePath);

  if (file.isShowingFullFile) {
    dispatch('loadCollapsedDiff', file)
      .then(() => dispatch('assignDiscussionsToDiff', getters.getDiffFileDiscussions(file)))
      .then(() => scrollToElement(`#${file.file_hash}`))
      .catch(() => dispatch('receiveFullDiffError', filePath));
  } else {
    dispatch('fetchFullDiff', file);
  }
};

export const setFileCollapsed = ({ commit }, { filePath, collapsed }) =>
  commit(types.SET_FILE_COLLAPSED, { filePath, collapsed });

// prevent babel-plugin-rewire from generating an invalid default during karma tests
export default () => {};
