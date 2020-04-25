import _ from 'underscore';
import { __ } from '../../../locale';
import service from '../../services';
import * as types from '../mutation_types';
import { decorateFiles } from '../../lib/files';

export const toggleTreeOpen = ({ commit }, path) => {
  commit(types.TOGGLE_TREE_OPEN, path);
};

export const showTreeEntry = ({ commit, dispatch, state }, path) => {
  const entry = state.entries[path];
  const parentPath = entry ? entry.parentPath : '';

  if (parentPath) {
    commit(types.SET_TREE_OPEN, parentPath);

    dispatch('showTreeEntry', parentPath);
  }
};

export const handleTreeEntryAction = ({ commit, dispatch }, row) => {
  if (row.type === 'tree') {
    dispatch('toggleTreeOpen', row.path);
  } else if (row.type === 'blob') {
    if (!row.opened) {
      commit(types.TOGGLE_FILE_OPEN, row.path);
    }

    dispatch('setFileActive', row.path);
  }

  dispatch('showTreeEntry', row.path);
};

export const setDirectoryData = ({ state, commit }, { projectId, branchId, treeList }) => {
  const selectedTree = state.trees[`${projectId}/${branchId}`];

  commit(types.SET_DIRECTORY_DATA, {
    treePath: `${projectId}/${branchId}`,
    data: treeList,
  });
  commit(types.TOGGLE_LOADING, {
    entry: selectedTree,
    forceValue: false,
  });
};

export const getFiles = ({ state, commit, dispatch }, payload = {}) =>
  new Promise((resolve, reject) => {
    const { projectId, branchId, ref = branchId } = payload;

    if (
      !state.trees[`${projectId}/${branchId}`] ||
      (state.trees[`${projectId}/${branchId}`].tree &&
        state.trees[`${projectId}/${branchId}`].tree.length === 0)
    ) {
      const selectedProject = state.projects[projectId];

      commit(types.CREATE_TREE, { treePath: `${projectId}/${branchId}` });
      service
        .getFiles(selectedProject.web_url, ref)
        .then(({ data }) => {
          const { entries, treeList } = decorateFiles({
            data,
            projectId,
            branchId,
          });

          commit(types.SET_ENTRIES, entries);

          // Defer setting the directory data because this triggers some intense rendering.
          // The entries is all we need to load the file editor.
          _.defer(() => dispatch('setDirectoryData', { projectId, branchId, treeList }));

          resolve();
        })
        .catch(e => {
          dispatch('setErrorMessage', {
            text: __('An error occurred while loading all the files.'),
            action: actionPayload =>
              dispatch('getFiles', actionPayload).then(() => dispatch('setErrorMessage', null)),
            actionText: __('Please try again'),
            actionPayload: { projectId, branchId },
          });
          reject(e);
        });
    } else {
      resolve();
    }
  });

export const restoreTree = ({ dispatch, commit, state }, path) => {
  const entry = state.entries[path];

  commit(types.RESTORE_TREE, path);

  if (entry.parentPath) {
    dispatch('restoreTree', entry.parentPath);
  }
};
