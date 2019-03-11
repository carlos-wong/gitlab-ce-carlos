import Vuex from 'vuex';
import { shallowMount, createLocalVue } from '@vue/test-utils';
import { GlLoadingIcon } from '@gitlab/ui';
import { TEST_HOST } from 'spec/test_constants';
import App from '~/diffs/components/app.vue';
import NoChanges from '~/diffs/components/no_changes.vue';
import DiffFile from '~/diffs/components/diff_file.vue';
import Mousetrap from 'mousetrap';
import CompareVersions from '~/diffs/components/compare_versions.vue';
import HiddenFilesWarning from '~/diffs/components/hidden_files_warning.vue';
import CommitWidget from '~/diffs/components/commit_widget.vue';
import TreeList from '~/diffs/components/tree_list.vue';
import createDiffsStore from '../create_diffs_store';
import diffsMockData from '../mock_data/merge_request_diffs';

const mergeRequestDiff = { version_index: 1 };

describe('diffs/components/app', () => {
  const oldMrTabs = window.mrTabs;
  let store;
  let wrapper;

  function createComponent(props = {}, extendStore = () => {}) {
    const localVue = createLocalVue();

    localVue.use(Vuex);

    store = createDiffsStore();
    store.state.diffs.isLoading = false;

    extendStore(store);

    wrapper = shallowMount(localVue.extend(App), {
      localVue,
      propsData: {
        endpoint: `${TEST_HOST}/diff/endpoint`,
        projectPath: 'namespace/project',
        currentUser: {},
        changesEmptyStateIllustration: '',
        ...props,
      },
      store,
    });
  }

  beforeEach(() => {
    // setup globals (needed for component to mount :/)
    window.mrTabs = jasmine.createSpyObj('mrTabs', ['resetViewContainer']);
    window.mrTabs.expandViewContainer = jasmine.createSpy();
  });

  afterEach(() => {
    // reset globals
    window.mrTabs = oldMrTabs;

    // reset component
    wrapper.destroy();
  });

  it('displays loading icon on loading', () => {
    createComponent({}, ({ state }) => {
      state.diffs.isLoading = true;
    });

    expect(wrapper.contains(GlLoadingIcon)).toBe(true);
  });

  it('displays diffs container when not loading', () => {
    createComponent();

    expect(wrapper.contains(GlLoadingIcon)).toBe(false);
    expect(wrapper.contains('#diffs')).toBe(true);
  });

  it('does not show commit info', () => {
    createComponent();

    expect(wrapper.contains('.blob-commit-info')).toBe(false);
  });

  describe('row highlighting', () => {
    beforeEach(() => {
      window.location.hash = 'ABC_123';
    });

    it('sets highlighted row if hash exists in location object', done => {
      createComponent({
        shouldShow: true,
      });

      // Component uses $nextTick so we wait until that has finished
      setTimeout(() => {
        expect(store.state.diffs.highlightedRow).toBe('ABC_123');

        done();
      });
    });

    it('marks current diff file based on currently highlighted row', done => {
      createComponent({
        shouldShow: true,
      });

      // Component uses $nextTick so we wait until that has finished
      setTimeout(() => {
        expect(store.state.diffs.currentDiffFileId).toBe('ABC');

        done();
      });
    });
  });

  describe('resizable', () => {
    afterEach(() => {
      localStorage.removeItem('mr_tree_list_width');
    });

    it('sets initial width when no localStorage has been set', () => {
      createComponent();

      expect(wrapper.vm.treeWidth).toEqual(320);
    });

    it('sets initial width to localStorage size', () => {
      localStorage.setItem('mr_tree_list_width', '200');

      createComponent();

      expect(wrapper.vm.treeWidth).toEqual(200);
    });

    it('sets width of tree list', () => {
      createComponent();

      expect(wrapper.find('.js-diff-tree-list').element.style.width).toEqual('320px');
    });
  });

  it('marks current diff file based on currently highlighted row', done => {
    createComponent({
      shouldShow: true,
    });

    // Component uses $nextTick so we wait until that has finished
    setTimeout(() => {
      expect(store.state.diffs.currentDiffFileId).toBe('ABC');

      done();
    });
  });

  describe('empty state', () => {
    it('renders empty state when no diff files exist', () => {
      createComponent();

      expect(wrapper.contains(NoChanges)).toBe(true);
    });

    it('does not render empty state when diff files exist', () => {
      createComponent({}, ({ state }) => {
        state.diffs.diffFiles.push({
          id: 1,
        });
      });

      expect(wrapper.contains(NoChanges)).toBe(false);
      expect(wrapper.findAll(DiffFile).length).toBe(1);
    });

    it('does not render empty state when versions match', () => {
      createComponent({}, ({ state }) => {
        state.diffs.startVersion = mergeRequestDiff;
        state.diffs.mergeRequestDiff = mergeRequestDiff;
      });

      expect(wrapper.contains(NoChanges)).toBe(false);
    });
  });

  describe('keyboard shortcut navigation', () => {
    const mappings = {
      '[': -1,
      k: -1,
      ']': +1,
      j: +1,
    };
    let spy;

    describe('visible app', () => {
      beforeEach(() => {
        spy = jasmine.createSpy('spy');

        createComponent({
          shouldShow: true,
        });
        wrapper.setMethods({
          jumpToFile: spy,
        });
      });

      it('calls `jumpToFile()` with correct parameter whenever pre-defined key is pressed', done => {
        wrapper.vm
          .$nextTick()
          .then(() => {
            Object.keys(mappings).forEach(function(key) {
              Mousetrap.trigger(key);

              expect(spy.calls.mostRecent().args).toEqual([mappings[key]]);
            });

            expect(spy.calls.count()).toEqual(Object.keys(mappings).length);
          })
          .then(done)
          .catch(done.fail);
      });

      it('does not call `jumpToFile()` when unknown key is pressed', done => {
        wrapper.vm
          .$nextTick()
          .then(() => {
            Mousetrap.trigger('d');

            expect(spy).not.toHaveBeenCalled();
          })
          .then(done)
          .catch(done.fail);
      });
    });

    describe('hideen app', () => {
      beforeEach(() => {
        spy = jasmine.createSpy('spy');

        createComponent({
          shouldShow: false,
        });
        wrapper.setMethods({
          jumpToFile: spy,
        });
      });

      it('stops calling `jumpToFile()` when application is hidden', done => {
        wrapper.vm
          .$nextTick()
          .then(() => {
            Object.keys(mappings).forEach(function(key) {
              Mousetrap.trigger(key);

              expect(spy).not.toHaveBeenCalled();
            });
          })
          .then(done)
          .catch(done.fail);
      });
    });
  });

  describe('jumpToFile', () => {
    let spy;

    beforeEach(() => {
      spy = jasmine.createSpy();

      createComponent({}, () => {
        store.state.diffs.diffFiles = [
          { file_hash: '111', file_path: '111.js' },
          { file_hash: '222', file_path: '222.js' },
          { file_hash: '333', file_path: '333.js' },
        ];
      });

      wrapper.setMethods({
        scrollToFile: spy,
      });
    });

    afterEach(() => {
      wrapper.destroy();
    });

    it('jumps to next and previous files in the list', done => {
      wrapper.vm
        .$nextTick()
        .then(() => {
          wrapper.vm.jumpToFile(+1);

          expect(spy.calls.mostRecent().args).toEqual(['222.js']);
          store.state.diffs.currentDiffFileId = '222';
          wrapper.vm.jumpToFile(+1);

          expect(spy.calls.mostRecent().args).toEqual(['333.js']);
          store.state.diffs.currentDiffFileId = '333';
          wrapper.vm.jumpToFile(-1);

          expect(spy.calls.mostRecent().args).toEqual(['222.js']);
        })
        .then(done)
        .catch(done.fail);
    });

    it('does not jump to previous file from the first one', done => {
      wrapper.vm
        .$nextTick()
        .then(() => {
          store.state.diffs.currentDiffFileId = '333';

          expect(wrapper.vm.currentDiffIndex).toEqual(2);

          wrapper.vm.jumpToFile(+1);

          expect(wrapper.vm.currentDiffIndex).toEqual(2);
          expect(spy).not.toHaveBeenCalled();
        })
        .then(done)
        .catch(done.fail);
    });

    it('does not jump to next file from the last one', done => {
      wrapper.vm
        .$nextTick()
        .then(() => {
          expect(wrapper.vm.currentDiffIndex).toEqual(0);

          wrapper.vm.jumpToFile(-1);

          expect(wrapper.vm.currentDiffIndex).toEqual(0);
          expect(spy).not.toHaveBeenCalled();
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('diffs', () => {
    it('should render compare versions component', () => {
      createComponent({}, ({ state }) => {
        state.diffs.mergeRequestDiffs = diffsMockData;
        state.diffs.targetBranchName = 'target-branch';
        state.diffs.mergeRequestDiff = mergeRequestDiff;
      });

      expect(wrapper.contains(CompareVersions)).toBe(true);
      expect(wrapper.find(CompareVersions).props()).toEqual(
        jasmine.objectContaining({
          targetBranch: {
            branchName: 'target-branch',
            versionIndex: -1,
            path: '',
          },
          mergeRequestDiffs: diffsMockData,
          mergeRequestDiff,
        }),
      );
    });

    it('should render hidden files warning if render overflow warning is present', () => {
      createComponent({}, ({ state }) => {
        state.diffs.renderOverflowWarning = true;
        state.diffs.realSize = '5';
        state.diffs.plainDiffPath = 'plain diff path';
        state.diffs.emailPatchPath = 'email patch path';
        state.diffs.size = 1;
      });

      expect(wrapper.contains(HiddenFilesWarning)).toBe(true);
      expect(wrapper.find(HiddenFilesWarning).props()).toEqual(
        jasmine.objectContaining({
          total: '5',
          plainDiffPath: 'plain diff path',
          emailPatchPath: 'email patch path',
          visible: 1,
        }),
      );
    });

    it('should display commit widget if store has a commit', () => {
      createComponent({}, () => {
        store.state.diffs.commit = {
          author: 'John Doe',
        };
      });

      expect(wrapper.contains(CommitWidget)).toBe(true);
    });

    it('should display diff file if there are diff files', () => {
      createComponent({}, ({ state }) => {
        state.diffs.diffFiles.push({ sha: '123' });
      });

      expect(wrapper.contains(DiffFile)).toBe(true);
    });

    it('should render tree list', () => {
      createComponent();

      expect(wrapper.find(TreeList).exists()).toBe(true);
    });
  });
});
