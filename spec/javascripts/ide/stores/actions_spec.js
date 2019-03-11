import actions, {
  stageAllChanges,
  unstageAllChanges,
  toggleFileFinder,
  setCurrentBranchId,
  setEmptyStateSvgs,
  updateActivityBarView,
  updateTempFlagForEntry,
  setErrorMessage,
  deleteEntry,
  renameEntry,
} from '~/ide/stores/actions';
import store from '~/ide/stores';
import * as types from '~/ide/stores/mutation_types';
import router from '~/ide/ide_router';
import { resetStore, file } from '../helpers';
import testAction from '../../helpers/vuex_action_helper';

describe('Multi-file store actions', () => {
  beforeEach(() => {
    spyOn(router, 'push');
  });

  afterEach(() => {
    resetStore(store);
  });

  describe('redirectToUrl', () => {
    it('calls visitUrl', done => {
      const visitUrl = spyOnDependency(actions, 'visitUrl');

      store
        .dispatch('redirectToUrl', 'test')
        .then(() => {
          expect(visitUrl).toHaveBeenCalledWith('test');

          done();
        })
        .catch(done.fail);
    });
  });

  describe('setInitialData', () => {
    it('commits initial data', done => {
      store
        .dispatch('setInitialData', { canCommit: true })
        .then(() => {
          expect(store.state.canCommit).toBeTruthy();
          done();
        })
        .catch(done.fail);
    });
  });

  describe('discardAllChanges', () => {
    beforeEach(() => {
      const f = file('discardAll');
      f.changed = true;

      store.state.openFiles.push(f);
      store.state.changedFiles.push(f);
      store.state.entries[f.path] = f;
    });

    it('discards changes in file', done => {
      store
        .dispatch('discardAllChanges')
        .then(() => {
          expect(store.state.openFiles.changed).toBeFalsy();
        })
        .then(done)
        .catch(done.fail);
    });

    it('removes all files from changedFiles state', done => {
      store
        .dispatch('discardAllChanges')
        .then(() => {
          expect(store.state.changedFiles.length).toBe(0);
          expect(store.state.openFiles.length).toBe(1);
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('closeAllFiles', () => {
    beforeEach(() => {
      const f = file('closeAll');
      store.state.openFiles.push(f);
      store.state.openFiles[0].opened = true;
      store.state.entries[f.path] = f;
    });

    it('closes all open files', done => {
      store
        .dispatch('closeAllFiles')
        .then(() => {
          expect(store.state.openFiles.length).toBe(0);

          done();
        })
        .catch(done.fail);
    });
  });

  describe('createTempEntry', () => {
    beforeEach(() => {
      document.body.innerHTML += '<div class="flash-container"></div>';

      store.state.currentProjectId = 'abcproject';
      store.state.currentBranchId = 'mybranch';

      store.state.trees['abcproject/mybranch'] = {
        tree: [],
      };
      store.state.projects.abcproject = {
        web_url: '',
      };
    });

    afterEach(() => {
      document.querySelector('.flash-container').remove();
    });

    describe('tree', () => {
      it('creates temp tree', done => {
        store
          .dispatch('createTempEntry', {
            branchId: store.state.currentBranchId,
            name: 'test',
            type: 'tree',
          })
          .then(() => {
            const entry = store.state.entries.test;

            expect(entry).not.toBeNull();
            expect(entry.type).toBe('tree');

            done();
          })
          .catch(done.fail);
      });

      it('creates new folder inside another tree', done => {
        const tree = {
          type: 'tree',
          name: 'testing',
          path: 'testing',
          tree: [],
        };

        store.state.entries[tree.path] = tree;

        store
          .dispatch('createTempEntry', {
            branchId: store.state.currentBranchId,
            name: 'testing/test',
            type: 'tree',
          })
          .then(() => {
            expect(tree.tree[0].tempFile).toBeTruthy();
            expect(tree.tree[0].name).toBe('test');
            expect(tree.tree[0].type).toBe('tree');

            done();
          })
          .catch(done.fail);
      });

      it('does not create new tree if already exists', done => {
        const tree = {
          type: 'tree',
          path: 'testing',
          tempFile: false,
          tree: [],
        };

        store.state.entries[tree.path] = tree;

        store
          .dispatch('createTempEntry', {
            branchId: store.state.currentBranchId,
            name: 'testing',
            type: 'tree',
          })
          .then(() => {
            expect(store.state.entries[tree.path].tempFile).toEqual(false);
            expect(document.querySelector('.flash-alert')).not.toBeNull();

            done();
          })
          .catch(done.fail);
      });
    });

    describe('blob', () => {
      it('creates temp file', done => {
        store
          .dispatch('createTempEntry', {
            name: 'test',
            branchId: 'mybranch',
            type: 'blob',
          })
          .then(f => {
            expect(f.tempFile).toBeTruthy();
            expect(store.state.trees['abcproject/mybranch'].tree.length).toBe(1);

            done();
          })
          .catch(done.fail);
      });

      it('adds tmp file to open files', done => {
        store
          .dispatch('createTempEntry', {
            name: 'test',
            branchId: 'mybranch',
            type: 'blob',
          })
          .then(f => {
            expect(store.state.openFiles.length).toBe(1);
            expect(store.state.openFiles[0].name).toBe(f.name);

            done();
          })
          .catch(done.fail);
      });

      it('adds tmp file to changed files', done => {
        store
          .dispatch('createTempEntry', {
            name: 'test',
            branchId: 'mybranch',
            type: 'blob',
          })
          .then(f => {
            expect(store.state.changedFiles.length).toBe(1);
            expect(store.state.changedFiles[0].name).toBe(f.name);

            done();
          })
          .catch(done.fail);
      });

      it('sets tmp file as active', done => {
        store
          .dispatch('createTempEntry', {
            name: 'test',
            branchId: 'mybranch',
            type: 'blob',
          })
          .then(f => {
            expect(f.active).toBeTruthy();

            done();
          })
          .catch(done.fail);
      });

      it('creates flash message if file already exists', done => {
        const f = file('test', '1', 'blob');
        store.state.trees['abcproject/mybranch'].tree = [f];
        store.state.entries[f.path] = f;

        store
          .dispatch('createTempEntry', {
            name: 'test',
            branchId: 'mybranch',
            type: 'blob',
          })
          .then(() => {
            expect(document.querySelector('.flash-alert')).not.toBeNull();

            done();
          })
          .catch(done.fail);
      });
    });
  });

  describe('scrollToTab', () => {
    it('focuses the current active element', done => {
      document.body.innerHTML +=
        '<div id="tabs"><div class="active"><div class="repo-tab"></div></div></div>';
      const el = document.querySelector('.repo-tab');
      spyOn(el, 'focus');

      store
        .dispatch('scrollToTab')
        .then(() => {
          setTimeout(() => {
            expect(el.focus).toHaveBeenCalled();

            document.getElementById('tabs').remove();

            done();
          });
        })
        .catch(done.fail);
    });
  });

  describe('stageAllChanges', () => {
    it('adds all files from changedFiles to stagedFiles', done => {
      const openFile = { ...file(), path: 'test' };

      store.state.openFiles.push(openFile);
      store.state.stagedFiles.push(openFile);
      store.state.changedFiles.push(openFile, file('new'));

      testAction(
        stageAllChanges,
        null,
        store.state,
        [
          { type: types.SET_LAST_COMMIT_MSG, payload: '' },
          { type: types.STAGE_CHANGE, payload: store.state.changedFiles[0].path },
          { type: types.STAGE_CHANGE, payload: store.state.changedFiles[1].path },
        ],
        [
          {
            type: 'openPendingTab',
            payload: { file: openFile, keyPrefix: 'staged' },
          },
        ],
        done,
      );
    });
  });

  describe('unstageAllChanges', () => {
    it('removes all files from stagedFiles after unstaging', done => {
      const openFile = { ...file(), path: 'test' };

      store.state.openFiles.push(openFile);
      store.state.changedFiles.push(openFile);
      store.state.stagedFiles.push(openFile, file('new'));

      testAction(
        unstageAllChanges,
        null,
        store.state,
        [
          { type: types.UNSTAGE_CHANGE, payload: store.state.stagedFiles[0].path },
          { type: types.UNSTAGE_CHANGE, payload: store.state.stagedFiles[1].path },
        ],
        [
          {
            type: 'openPendingTab',
            payload: { file: openFile, keyPrefix: 'unstaged' },
          },
        ],
        done,
      );
    });
  });

  describe('updateViewer', () => {
    it('updates viewer state', done => {
      store
        .dispatch('updateViewer', 'diff')
        .then(() => {
          expect(store.state.viewer).toBe('diff');
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('updateActivityBarView', () => {
    it('commits UPDATE_ACTIVITY_BAR_VIEW', done => {
      testAction(
        updateActivityBarView,
        'test',
        {},
        [{ type: 'UPDATE_ACTIVITY_BAR_VIEW', payload: 'test' }],
        [],
        done,
      );
    });
  });

  describe('setEmptyStateSvgs', () => {
    it('commits setEmptyStateSvgs', done => {
      testAction(
        setEmptyStateSvgs,
        'svg',
        {},
        [{ type: 'SET_EMPTY_STATE_SVGS', payload: 'svg' }],
        [],
        done,
      );
    });
  });

  describe('updateTempFlagForEntry', () => {
    it('commits UPDATE_TEMP_FLAG', done => {
      const f = {
        ...file(),
        path: 'test',
        tempFile: true,
      };
      store.state.entries[f.path] = f;

      testAction(
        updateTempFlagForEntry,
        { file: f, tempFile: false },
        store.state,
        [{ type: 'UPDATE_TEMP_FLAG', payload: { path: f.path, tempFile: false } }],
        [],
        done,
      );
    });

    it('commits UPDATE_TEMP_FLAG and dispatches for parent', done => {
      const parent = {
        ...file(),
        path: 'testing',
      };
      const f = {
        ...file(),
        path: 'test',
        parentPath: 'testing',
      };
      store.state.entries[parent.path] = parent;
      store.state.entries[f.path] = f;

      testAction(
        updateTempFlagForEntry,
        { file: f, tempFile: false },
        store.state,
        [{ type: 'UPDATE_TEMP_FLAG', payload: { path: f.path, tempFile: false } }],
        [{ type: 'updateTempFlagForEntry', payload: { file: parent, tempFile: false } }],
        done,
      );
    });
  });

  describe('setCurrentBranchId', () => {
    it('commits setCurrentBranchId', done => {
      testAction(
        setCurrentBranchId,
        'branchId',
        {},
        [{ type: 'SET_CURRENT_BRANCH', payload: 'branchId' }],
        [],
        done,
      );
    });
  });

  describe('toggleFileFinder', () => {
    it('commits TOGGLE_FILE_FINDER', done => {
      testAction(
        toggleFileFinder,
        true,
        null,
        [{ type: 'TOGGLE_FILE_FINDER', payload: true }],
        [],
        done,
      );
    });
  });

  describe('setErrorMessage', () => {
    it('commis error messsage', done => {
      testAction(
        setErrorMessage,
        'error',
        null,
        [{ type: types.SET_ERROR_MESSAGE, payload: 'error' }],
        [],
        done,
      );
    });
  });

  describe('deleteEntry', () => {
    it('commits entry deletion', done => {
      store.state.entries.path = 'testing';

      testAction(
        deleteEntry,
        'path',
        store.state,
        [{ type: types.DELETE_ENTRY, payload: 'path' }],
        [{ type: 'burstUnusedSeal' }],
        done,
      );
    });
  });

  describe('renameEntry', () => {
    it('renames entry', done => {
      store.state.entries.test = {
        tree: [],
      };

      testAction(
        renameEntry,
        { path: 'test', name: 'new-name', entryPath: null, parentPath: 'parent-path' },
        store.state,
        [
          {
            type: types.RENAME_ENTRY,
            payload: { path: 'test', name: 'new-name', entryPath: null, parentPath: 'parent-path' },
          },
        ],
        [{ type: 'deleteEntry', payload: 'test' }],
        done,
      );
    });

    it('renames all entries in tree', done => {
      store.state.entries.test = {
        type: 'tree',
        tree: [
          {
            path: 'tree-1',
          },
          {
            path: 'tree-2',
          },
        ],
      };

      testAction(
        renameEntry,
        { path: 'test', name: 'new-name', parentPath: 'parent-path' },
        store.state,
        [
          {
            type: types.RENAME_ENTRY,
            payload: { path: 'test', name: 'new-name', entryPath: null, parentPath: 'parent-path' },
          },
        ],
        [
          {
            type: 'renameEntry',
            payload: {
              path: 'test',
              name: 'new-name',
              entryPath: 'tree-1',
              parentPath: 'parent-path/new-name',
            },
          },
          {
            type: 'renameEntry',
            payload: {
              path: 'test',
              name: 'new-name',
              entryPath: 'tree-2',
              parentPath: 'parent-path/new-name',
            },
          },
          { type: 'deleteEntry', payload: 'test' },
        ],
        done,
      );
    });
  });
});
