import Vue from 'vue';
import * as types from './mutation_types';
import projectMutations from './mutations/project';
import mergeRequestMutation from './mutations/merge_request';
import fileMutations from './mutations/file';
import treeMutations from './mutations/tree';
import branchMutations from './mutations/branch';
import {
  sortTree,
  replaceFileUrl,
  swapInParentTreeWithSorting,
  updateFileCollections,
  removeFromParentTree,
  pathsAreEqual,
} from './utils';

export default {
  [types.SET_INITIAL_DATA](state, data) {
    Object.assign(state, data);
  },
  [types.TOGGLE_LOADING](state, { entry, forceValue = undefined }) {
    if (entry.path) {
      Object.assign(state.entries[entry.path], {
        loading: forceValue !== undefined ? forceValue : !state.entries[entry.path].loading,
      });
    } else {
      Object.assign(entry, {
        loading: forceValue !== undefined ? forceValue : !entry.loading,
      });
    }
  },
  [types.SET_LEFT_PANEL_COLLAPSED](state, collapsed) {
    Object.assign(state, {
      leftPanelCollapsed: collapsed,
    });
  },
  [types.SET_RIGHT_PANEL_COLLAPSED](state, collapsed) {
    Object.assign(state, {
      rightPanelCollapsed: collapsed,
    });
  },
  [types.SET_RESIZING_STATUS](state, resizing) {
    Object.assign(state, {
      panelResizing: resizing,
    });
  },
  [types.SET_LAST_COMMIT_DATA](state, { entry, lastCommit }) {
    Object.assign(entry.lastCommit, {
      id: lastCommit.commit.id,
      url: lastCommit.commit_path,
      message: lastCommit.commit.message,
      author: lastCommit.commit.author_name,
      updatedAt: lastCommit.commit.authored_date,
    });
  },
  [types.SET_LAST_COMMIT_MSG](state, lastCommitMsg) {
    Object.assign(state, {
      lastCommitMsg,
    });
  },
  [types.CLEAR_STAGED_CHANGES](state) {
    Object.assign(state, {
      stagedFiles: [],
    });
  },
  [types.SET_ENTRIES](state, entries) {
    Object.assign(state, {
      entries,
    });
  },
  [types.CREATE_TMP_ENTRY](state, { data, projectId, branchId }) {
    Object.keys(data.entries).reduce((acc, key) => {
      const entry = data.entries[key];
      const foundEntry = state.entries[key];

      // NOTE: We can't clone `entry` in any of the below assignments because
      // we need `state.entries` and the `entry.tree` to reference the same object.
      if (!foundEntry) {
        Object.assign(state.entries, {
          [key]: entry,
        });
      } else if (foundEntry.deleted) {
        Object.assign(state.entries, {
          [key]: Object.assign(entry, { replaces: true }),
        });
      } else {
        const tree = entry.tree.filter(
          f => foundEntry.tree.find(e => e.path === f.path) === undefined,
        );
        Object.assign(foundEntry, {
          tree: sortTree(foundEntry.tree.concat(tree)),
        });
      }

      return acc.concat(key);
    }, []);

    const foundEntry = state.trees[`${projectId}/${branchId}`].tree.find(
      e => e.path === data.treeList[0].path,
    );

    if (!foundEntry) {
      Object.assign(state.trees[`${projectId}/${branchId}`], {
        tree: sortTree(state.trees[`${projectId}/${branchId}`].tree.concat(data.treeList)),
      });
    }
  },
  [types.UPDATE_TEMP_FLAG](state, { path, tempFile }) {
    Object.assign(state.entries[path], {
      tempFile,
      changed: tempFile,
    });
  },
  [types.UPDATE_VIEWER](state, viewer) {
    Object.assign(state, {
      viewer,
    });
  },
  [types.UPDATE_DELAY_VIEWER_CHANGE](state, delayViewerUpdated) {
    Object.assign(state, {
      delayViewerUpdated,
    });
  },
  [types.UPDATE_ACTIVITY_BAR_VIEW](state, currentActivityView) {
    Object.assign(state, {
      currentActivityView,
    });
  },
  [types.SET_EMPTY_STATE_SVGS](
    state,
    {
      emptyStateSvgPath,
      noChangesStateSvgPath,
      committedStateSvgPath,
      pipelinesEmptyStateSvgPath,
      promotionSvgPath,
    },
  ) {
    Object.assign(state, {
      emptyStateSvgPath,
      noChangesStateSvgPath,
      committedStateSvgPath,
      pipelinesEmptyStateSvgPath,
      promotionSvgPath,
    });
  },
  [types.TOGGLE_FILE_FINDER](state, fileFindVisible) {
    Object.assign(state, {
      fileFindVisible,
    });
  },
  [types.UPDATE_FILE_AFTER_COMMIT](state, { file, lastCommit }) {
    const changedFile = state.changedFiles.find(f => f.path === file.path);
    const { prevPath } = file;

    Object.assign(state.entries[file.path], {
      raw: file.content,
      changed: Boolean(changedFile),
      staged: false,
      replaces: false,
      lastCommitSha: lastCommit.commit.id,

      prevId: undefined,
      prevPath: undefined,
      prevName: undefined,
      prevUrl: undefined,
      prevKey: undefined,
      prevParentPath: undefined,
    });

    if (prevPath) {
      // Update URLs after file has moved
      const regex = new RegExp(`${prevPath}$`);

      Object.assign(state.entries[file.path], {
        rawPath: file.rawPath.replace(regex, file.path),
        permalink: file.permalink.replace(regex, file.path),
        commitsPath: file.commitsPath.replace(regex, file.path),
        blamePath: file.blamePath.replace(regex, file.path),
      });
    }
  },
  [types.SET_LINKS](state, links) {
    Object.assign(state, { links });
  },
  [types.CLEAR_PROJECTS](state) {
    Object.assign(state, { projects: {}, trees: {} });
  },
  [types.RESET_OPEN_FILES](state) {
    Object.assign(state, { openFiles: [] });
  },
  [types.SET_ERROR_MESSAGE](state, errorMessage) {
    Object.assign(state, { errorMessage });
  },
  [types.OPEN_NEW_ENTRY_MODAL](state, { type, path }) {
    Object.assign(state, {
      entryModal: {
        type,
        path,
        entry: { ...state.entries[path] },
      },
    });
  },
  [types.DELETE_ENTRY](state, path) {
    const entry = state.entries[path];
    const { tempFile = false } = entry;
    const parent = entry.parentPath
      ? state.entries[entry.parentPath]
      : state.trees[`${state.currentProjectId}/${state.currentBranchId}`];

    entry.deleted = true;

    if (parent) {
      parent.tree = parent.tree.filter(f => f.path !== entry.path);
    }

    if (entry.type === 'blob') {
      if (tempFile) {
        state.changedFiles = state.changedFiles.filter(f => f.path !== path);
      } else {
        state.changedFiles = state.changedFiles.concat(entry);
      }
    }

    state.unusedSeal = false;
  },
  [types.RENAME_ENTRY](state, { path, name, parentPath }) {
    const oldEntry = state.entries[path];
    const newPath = parentPath ? `${parentPath}/${name}` : name;
    const isRevert = newPath === oldEntry.prevPath;

    const newUrl = replaceFileUrl(oldEntry.url, oldEntry.path, newPath);

    const newKey = oldEntry.key.replace(new RegExp(oldEntry.path, 'g'), newPath);

    const baseProps = {
      ...oldEntry,
      name,
      id: newPath,
      path: newPath,
      url: newUrl,
      key: newKey,
      parentPath: parentPath || '',
    };

    const prevProps =
      oldEntry.tempFile || isRevert
        ? {
            prevId: undefined,
            prevPath: undefined,
            prevName: undefined,
            prevUrl: undefined,
            prevKey: undefined,
            prevParentPath: undefined,
          }
        : {
            prevId: oldEntry.prevId || oldEntry.id,
            prevPath: oldEntry.prevPath || oldEntry.path,
            prevName: oldEntry.prevName || oldEntry.name,
            prevUrl: oldEntry.prevUrl || oldEntry.url,
            prevKey: oldEntry.prevKey || oldEntry.key,
            prevParentPath: oldEntry.prevParentPath || oldEntry.parentPath,
          };

    Vue.set(state.entries, newPath, {
      ...baseProps,
      ...prevProps,
    });

    if (pathsAreEqual(oldEntry.parentPath, parentPath)) {
      swapInParentTreeWithSorting(state, oldEntry.key, newPath, parentPath);
    } else {
      removeFromParentTree(state, oldEntry.key, oldEntry.parentPath);
      swapInParentTreeWithSorting(state, oldEntry.key, newPath, parentPath);
    }

    if (oldEntry.type === 'blob') {
      updateFileCollections(state, oldEntry.key, newPath);
    }

    Vue.delete(state.entries, oldEntry.path);
  },

  ...projectMutations,
  ...mergeRequestMutation,
  ...fileMutations,
  ...treeMutations,
  ...branchMutations,
};
