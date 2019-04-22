import MockAdapter from 'axios-mock-adapter';
import Cookies from 'js-cookie';
import {
  DIFF_VIEW_COOKIE_NAME,
  INLINE_DIFF_VIEW_TYPE,
  PARALLEL_DIFF_VIEW_TYPE,
} from '~/diffs/constants';
import actions, {
  setBaseConfig,
  fetchDiffFiles,
  assignDiscussionsToDiff,
  removeDiscussionsFromDiff,
  startRenderDiffsQueue,
  setInlineDiffViewType,
  setParallelDiffViewType,
  showCommentForm,
  cancelCommentForm,
  loadMoreLines,
  scrollToLineIfNeededInline,
  scrollToLineIfNeededParallel,
  loadCollapsedDiff,
  expandAllFiles,
  toggleFileDiscussions,
  saveDiffDiscussion,
  setHighlightedRow,
  toggleTreeOpen,
  scrollToFile,
  toggleShowTreeList,
  renderFileForDiscussionId,
  setRenderTreeList,
  setShowWhitespace,
  setRenderIt,
  requestFullDiff,
  receiveFullDiffSucess,
  receiveFullDiffError,
  fetchFullDiff,
  toggleFullDiff,
  setFileCollapsed,
} from '~/diffs/store/actions';
import eventHub from '~/notes/event_hub';
import * as types from '~/diffs/store/mutation_types';
import axios from '~/lib/utils/axios_utils';
import mockDiffFile from 'spec/diffs/mock_data/diff_file';
import testAction from '../../helpers/vuex_action_helper';

describe('DiffsStoreActions', () => {
  const originalMethods = {
    requestAnimationFrame: global.requestAnimationFrame,
    requestIdleCallback: global.requestIdleCallback,
  };

  beforeEach(() => {
    ['requestAnimationFrame', 'requestIdleCallback'].forEach(method => {
      global[method] = cb => {
        cb();
      };
    });
  });

  afterEach(() => {
    ['requestAnimationFrame', 'requestIdleCallback'].forEach(method => {
      global[method] = originalMethods[method];
    });
  });

  describe('setBaseConfig', () => {
    it('should set given endpoint and project path', done => {
      const endpoint = '/diffs/set/endpoint';
      const projectPath = '/root/project';

      testAction(
        setBaseConfig,
        { endpoint, projectPath },
        { endpoint: '', projectPath: '' },
        [{ type: types.SET_BASE_CONFIG, payload: { endpoint, projectPath } }],
        [],
        done,
      );
    });
  });

  describe('fetchDiffFiles', () => {
    it('should fetch diff files', done => {
      const endpoint = '/fetch/diff/files';
      const mock = new MockAdapter(axios);
      const res = { diff_files: 1, merge_request_diffs: [] };
      mock.onGet(endpoint).reply(200, res);

      testAction(
        fetchDiffFiles,
        {},
        { endpoint },
        [
          { type: types.SET_LOADING, payload: true },
          { type: types.SET_LOADING, payload: false },
          { type: types.SET_MERGE_REQUEST_DIFFS, payload: res.merge_request_diffs },
          { type: types.SET_DIFF_DATA, payload: res },
        ],
        [],
        () => {
          mock.restore();
          done();
        },
      );
    });
  });

  describe('setHighlightedRow', () => {
    it('should mark currently selected diff and set lineHash and fileHash of highlightedRow', () => {
      testAction(setHighlightedRow, 'ABC_123', {}, [
        { type: types.SET_HIGHLIGHTED_ROW, payload: 'ABC_123' },
        { type: types.UPDATE_CURRENT_DIFF_FILE_ID, payload: 'ABC' },
      ]);
    });
  });

  describe('assignDiscussionsToDiff', () => {
    it('should merge discussions into diffs', done => {
      const state = {
        diffFiles: [
          {
            file_hash: 'ABC',
            parallel_diff_lines: [
              {
                left: {
                  line_code: 'ABC_1_1',
                  discussions: [],
                },
                right: {
                  line_code: 'ABC_1_1',
                  discussions: [],
                },
              },
            ],
            highlighted_diff_lines: [
              {
                line_code: 'ABC_1_1',
                discussions: [],
                old_line: 5,
                new_line: null,
              },
            ],
            diff_refs: {
              base_sha: 'abc',
              head_sha: 'def',
              start_sha: 'ghi',
            },
            new_path: 'file1',
            old_path: 'file2',
          },
        ],
      };

      const diffPosition = {
        base_sha: 'abc',
        head_sha: 'def',
        start_sha: 'ghi',
        new_line: null,
        new_path: 'file1',
        old_line: 5,
        old_path: 'file2',
      };

      const singleDiscussion = {
        line_code: 'ABC_1_1',
        diff_discussion: {},
        diff_file: {
          file_hash: 'ABC',
        },
        file_hash: 'ABC',
        resolvable: true,
        position: diffPosition,
        original_position: diffPosition,
      };

      const discussions = [singleDiscussion];

      testAction(
        assignDiscussionsToDiff,
        discussions,
        state,
        [
          {
            type: types.SET_LINE_DISCUSSIONS_FOR_FILE,
            payload: {
              discussion: singleDiscussion,
              diffPositionByLineCode: {
                ABC_1_1: {
                  base_sha: 'abc',
                  head_sha: 'def',
                  start_sha: 'ghi',
                  new_line: null,
                  new_path: 'file1',
                  old_line: 5,
                  old_path: 'file2',
                  line_code: 'ABC_1_1',
                  position_type: 'text',
                },
              },
            },
          },
        ],
        [],
        done,
      );
    });
  });

  describe('removeDiscussionsFromDiff', () => {
    it('should remove discussions from diffs', done => {
      const state = {
        diffFiles: [
          {
            file_hash: 'ABC',
            parallel_diff_lines: [
              {
                left: {
                  line_code: 'ABC_1_1',
                  discussions: [
                    {
                      id: 1,
                    },
                  ],
                },
                right: {
                  line_code: 'ABC_1_1',
                  discussions: [],
                },
              },
            ],
            highlighted_diff_lines: [
              {
                line_code: 'ABC_1_1',
                discussions: [],
              },
            ],
          },
        ],
      };
      const singleDiscussion = {
        id: '1',
        file_hash: 'ABC',
        line_code: 'ABC_1_1',
      };

      testAction(
        removeDiscussionsFromDiff,
        singleDiscussion,
        state,
        [
          {
            type: types.REMOVE_LINE_DISCUSSIONS_FOR_FILE,
            payload: {
              id: '1',
              fileHash: 'ABC',
              lineCode: 'ABC_1_1',
            },
          },
        ],
        [],
        done,
      );
    });
  });

  describe('startRenderDiffsQueue', () => {
    it('should set all files to RENDER_FILE', () => {
      const state = {
        diffFiles: [
          {
            id: 1,
            renderIt: false,
            viewer: {
              collapsed: false,
            },
          },
          {
            id: 2,
            renderIt: false,
            viewer: {
              collapsed: false,
            },
          },
        ],
      };

      const pseudoCommit = (commitType, file) => {
        expect(commitType).toBe(types.RENDER_FILE);
        Object.assign(file, {
          renderIt: true,
        });
      };

      startRenderDiffsQueue({ state, commit: pseudoCommit });

      expect(state.diffFiles[0].renderIt).toBe(true);
      expect(state.diffFiles[1].renderIt).toBe(true);
    });
  });

  describe('setInlineDiffViewType', () => {
    it('should set diff view type to inline and also set the cookie properly', done => {
      testAction(
        setInlineDiffViewType,
        null,
        {},
        [{ type: types.SET_DIFF_VIEW_TYPE, payload: INLINE_DIFF_VIEW_TYPE }],
        [],
        () => {
          setTimeout(() => {
            expect(Cookies.get('diff_view')).toEqual(INLINE_DIFF_VIEW_TYPE);
            done();
          }, 0);
        },
      );
    });
  });

  describe('setParallelDiffViewType', () => {
    it('should set diff view type to parallel and also set the cookie properly', done => {
      testAction(
        setParallelDiffViewType,
        null,
        {},
        [{ type: types.SET_DIFF_VIEW_TYPE, payload: PARALLEL_DIFF_VIEW_TYPE }],
        [],
        () => {
          setTimeout(() => {
            expect(Cookies.get(DIFF_VIEW_COOKIE_NAME)).toEqual(PARALLEL_DIFF_VIEW_TYPE);
            done();
          }, 0);
        },
      );
    });
  });

  describe('showCommentForm', () => {
    it('should call mutation to show comment form', done => {
      const payload = { lineCode: 'lineCode', fileHash: 'hash' };

      testAction(
        showCommentForm,
        payload,
        {},
        [{ type: types.TOGGLE_LINE_HAS_FORM, payload: { ...payload, hasForm: true } }],
        [],
        done,
      );
    });
  });

  describe('cancelCommentForm', () => {
    it('should call mutation to cancel comment form', done => {
      const payload = { lineCode: 'lineCode', fileHash: 'hash' };

      testAction(
        cancelCommentForm,
        payload,
        {},
        [{ type: types.TOGGLE_LINE_HAS_FORM, payload: { ...payload, hasForm: false } }],
        [],
        done,
      );
    });
  });

  describe('loadMoreLines', () => {
    it('should call mutation to show comment form', done => {
      const endpoint = '/diffs/load/more/lines';
      const params = { since: 6, to: 26 };
      const lineNumbers = { oldLineNumber: 3, newLineNumber: 5 };
      const fileHash = 'ff9200';
      const options = { endpoint, params, lineNumbers, fileHash };
      const mock = new MockAdapter(axios);
      const contextLines = { contextLines: [{ lineCode: 6 }] };
      mock.onGet(endpoint).reply(200, contextLines);

      testAction(
        loadMoreLines,
        options,
        {},
        [
          {
            type: types.ADD_CONTEXT_LINES,
            payload: { lineNumbers, contextLines, params, fileHash },
          },
        ],
        [],
        () => {
          mock.restore();
          done();
        },
      );
    });
  });

  describe('loadCollapsedDiff', () => {
    it('should fetch data and call mutation with response and the give parameter', done => {
      const file = { hash: 123, load_collapsed_diff_url: '/load/collapsed/diff/url' };
      const data = { hash: 123, parallelDiffLines: [{ lineCode: 1 }] };
      const mock = new MockAdapter(axios);
      const commit = jasmine.createSpy('commit');
      mock.onGet(file.loadCollapsedDiffUrl).reply(200, data);

      loadCollapsedDiff({ commit, getters: { commitId: null } }, file)
        .then(() => {
          expect(commit).toHaveBeenCalledWith(types.ADD_COLLAPSED_DIFFS, { file, data });

          mock.restore();
          done();
        })
        .catch(done.fail);
    });

    it('should fetch data without commit ID', () => {
      const file = { load_collapsed_diff_url: '/load/collapsed/diff/url' };
      const getters = {
        commitId: null,
      };

      spyOn(axios, 'get').and.returnValue(Promise.resolve({ data: {} }));

      loadCollapsedDiff({ commit() {}, getters }, file);

      expect(axios.get).toHaveBeenCalledWith(file.load_collapsed_diff_url, {
        params: { commit_id: null },
      });
    });

    it('should fetch data with commit ID', () => {
      const file = { load_collapsed_diff_url: '/load/collapsed/diff/url' };
      const getters = {
        commitId: '123',
      };

      spyOn(axios, 'get').and.returnValue(Promise.resolve({ data: {} }));

      loadCollapsedDiff({ commit() {}, getters }, file);

      expect(axios.get).toHaveBeenCalledWith(file.load_collapsed_diff_url, {
        params: { commit_id: '123' },
      });
    });
  });

  describe('expandAllFiles', () => {
    it('should change the collapsed prop from the diffFiles', done => {
      testAction(
        expandAllFiles,
        null,
        {},
        [
          {
            type: types.EXPAND_ALL_FILES,
          },
        ],
        [],
        done,
      );
    });
  });

  describe('toggleFileDiscussions', () => {
    it('should dispatch collapseDiscussion when all discussions are expanded', () => {
      const getters = {
        getDiffFileDiscussions: jasmine.createSpy().and.returnValue([{ id: 1 }]),
        diffHasAllExpandedDiscussions: jasmine.createSpy().and.returnValue(true),
        diffHasAllCollapsedDiscussions: jasmine.createSpy().and.returnValue(false),
      };

      const dispatch = jasmine.createSpy('dispatch');

      toggleFileDiscussions({ getters, dispatch });

      expect(dispatch).toHaveBeenCalledWith(
        'collapseDiscussion',
        { discussionId: 1 },
        { root: true },
      );
    });

    it('should dispatch expandDiscussion when all discussions are collapsed', () => {
      const getters = {
        getDiffFileDiscussions: jasmine.createSpy().and.returnValue([{ id: 1 }]),
        diffHasAllExpandedDiscussions: jasmine.createSpy().and.returnValue(false),
        diffHasAllCollapsedDiscussions: jasmine.createSpy().and.returnValue(true),
      };

      const dispatch = jasmine.createSpy();

      toggleFileDiscussions({ getters, dispatch });

      expect(dispatch).toHaveBeenCalledWith(
        'expandDiscussion',
        { discussionId: 1 },
        { root: true },
      );
    });

    it('should dispatch expandDiscussion when some discussions are collapsed and others are expanded for the collapsed discussion', () => {
      const getters = {
        getDiffFileDiscussions: jasmine.createSpy().and.returnValue([{ expanded: false, id: 1 }]),
        diffHasAllExpandedDiscussions: jasmine.createSpy().and.returnValue(false),
        diffHasAllCollapsedDiscussions: jasmine.createSpy().and.returnValue(false),
      };

      const dispatch = jasmine.createSpy();

      toggleFileDiscussions({ getters, dispatch });

      expect(dispatch).toHaveBeenCalledWith(
        'expandDiscussion',
        { discussionId: 1 },
        { root: true },
      );
    });
  });

  describe('scrollToLineIfNeededInline', () => {
    const lineMock = {
      line_code: 'ABC_123',
    };

    it('should not call handleLocationHash when there is not hash', () => {
      window.location.hash = '';

      const handleLocationHashSpy = spyOnDependency(actions, 'handleLocationHash').and.stub();

      scrollToLineIfNeededInline({}, lineMock);

      expect(handleLocationHashSpy).not.toHaveBeenCalled();
    });

    it('should not call handleLocationHash when the hash does not match any line', () => {
      window.location.hash = 'XYZ_456';

      const handleLocationHashSpy = spyOnDependency(actions, 'handleLocationHash').and.stub();

      scrollToLineIfNeededInline({}, lineMock);

      expect(handleLocationHashSpy).not.toHaveBeenCalled();
    });

    it('should call handleLocationHash only when the hash matches a line', () => {
      window.location.hash = 'ABC_123';

      const handleLocationHashSpy = spyOnDependency(actions, 'handleLocationHash').and.stub();

      scrollToLineIfNeededInline(
        {},
        {
          lineCode: 'ABC_456',
        },
      );
      scrollToLineIfNeededInline({}, lineMock);
      scrollToLineIfNeededInline(
        {},
        {
          lineCode: 'XYZ_456',
        },
      );

      expect(handleLocationHashSpy).toHaveBeenCalled();
      expect(handleLocationHashSpy).toHaveBeenCalledTimes(1);
    });
  });

  describe('scrollToLineIfNeededParallel', () => {
    const lineMock = {
      left: null,
      right: {
        line_code: 'ABC_123',
      },
    };

    it('should not call handleLocationHash when there is not hash', () => {
      window.location.hash = '';

      const handleLocationHashSpy = spyOnDependency(actions, 'handleLocationHash').and.stub();

      scrollToLineIfNeededParallel({}, lineMock);

      expect(handleLocationHashSpy).not.toHaveBeenCalled();
    });

    it('should not call handleLocationHash when the hash does not match any line', () => {
      window.location.hash = 'XYZ_456';

      const handleLocationHashSpy = spyOnDependency(actions, 'handleLocationHash').and.stub();

      scrollToLineIfNeededParallel({}, lineMock);

      expect(handleLocationHashSpy).not.toHaveBeenCalled();
    });

    it('should call handleLocationHash only when the hash matches a line', () => {
      window.location.hash = 'ABC_123';

      const handleLocationHashSpy = spyOnDependency(actions, 'handleLocationHash').and.stub();

      scrollToLineIfNeededParallel(
        {},
        {
          left: null,
          right: {
            lineCode: 'ABC_456',
          },
        },
      );
      scrollToLineIfNeededParallel({}, lineMock);
      scrollToLineIfNeededParallel(
        {},
        {
          left: null,
          right: {
            lineCode: 'XYZ_456',
          },
        },
      );

      expect(handleLocationHashSpy).toHaveBeenCalled();
      expect(handleLocationHashSpy).toHaveBeenCalledTimes(1);
    });
  });

  describe('saveDiffDiscussion', () => {
    it('dispatches actions', done => {
      const commitId = 'something';
      const formData = {
        diffFile: { ...mockDiffFile },
        noteableData: {},
      };
      const note = {};
      const state = {
        commit: {
          id: commitId,
        },
      };
      const dispatch = jasmine.createSpy('dispatch').and.callFake(name => {
        switch (name) {
          case 'saveNote':
            return Promise.resolve({
              discussion: 'test',
            });
          case 'updateDiscussion':
            return Promise.resolve('discussion');
          default:
            return Promise.resolve({});
        }
      });

      saveDiffDiscussion({ state, dispatch }, { note, formData })
        .then(() => {
          const { calls } = dispatch;

          expect(calls.count()).toBe(5);
          expect(calls.argsFor(0)).toEqual(['saveNote', jasmine.any(Object), { root: true }]);

          const postData = calls.argsFor(0)[1];

          expect(postData.data.note.commit_id).toBe(commitId);

          expect(calls.argsFor(1)).toEqual(['updateDiscussion', 'test', { root: true }]);
          expect(calls.argsFor(2)).toEqual(['assignDiscussionsToDiff', ['discussion']]);
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('toggleTreeOpen', () => {
    it('commits TOGGLE_FOLDER_OPEN', done => {
      testAction(
        toggleTreeOpen,
        'path',
        {},
        [{ type: types.TOGGLE_FOLDER_OPEN, payload: 'path' }],
        [],
        done,
      );
    });
  });

  describe('scrollToFile', () => {
    let commit;

    beforeEach(() => {
      commit = jasmine.createSpy();
      jasmine.clock().install();
    });

    afterEach(() => {
      jasmine.clock().uninstall();
    });

    it('updates location hash', () => {
      const state = {
        treeEntries: {
          path: {
            fileHash: 'test',
          },
        },
      };

      scrollToFile({ state, commit }, 'path');

      expect(document.location.hash).toBe('#test');
    });

    it('commits UPDATE_CURRENT_DIFF_FILE_ID', () => {
      const state = {
        treeEntries: {
          path: {
            fileHash: 'test',
          },
        },
      };

      scrollToFile({ state, commit }, 'path');

      expect(commit).toHaveBeenCalledWith(types.UPDATE_CURRENT_DIFF_FILE_ID, 'test');
    });
  });

  describe('toggleShowTreeList', () => {
    it('commits toggle', done => {
      testAction(toggleShowTreeList, null, {}, [{ type: types.TOGGLE_SHOW_TREE_LIST }], [], done);
    });

    it('updates localStorage', () => {
      spyOn(localStorage, 'setItem');

      toggleShowTreeList({ commit() {}, state: { showTreeList: true } });

      expect(localStorage.setItem).toHaveBeenCalledWith('mr_tree_show', true);
    });

    it('does not update localStorage', () => {
      spyOn(localStorage, 'setItem');

      toggleShowTreeList({ commit() {}, state: { showTreeList: true } }, false);

      expect(localStorage.setItem).not.toHaveBeenCalled();
    });
  });

  describe('renderFileForDiscussionId', () => {
    const rootState = {
      notes: {
        discussions: [
          {
            id: '123',
            diff_file: {
              file_hash: 'HASH',
            },
          },
          {
            id: '456',
            diff_file: {
              file_hash: 'HASH',
            },
          },
        ],
      },
    };
    let commit;
    let $emit;
    let scrollToElement;
    const state = ({ collapsed, renderIt }) => ({
      diffFiles: [
        {
          file_hash: 'HASH',
          viewer: {
            collapsed,
          },
          renderIt,
        },
      ],
    });

    beforeEach(() => {
      commit = jasmine.createSpy('commit');
      scrollToElement = spyOnDependency(actions, 'scrollToElement').and.stub();
      $emit = spyOn(eventHub, '$emit');
    });

    it('renders and expands file for the given discussion id', () => {
      const localState = state({ collapsed: true, renderIt: false });

      renderFileForDiscussionId({ rootState, state: localState, commit }, '123');

      expect(commit).toHaveBeenCalledWith('RENDER_FILE', localState.diffFiles[0]);
      expect($emit).toHaveBeenCalledTimes(1);
      expect(scrollToElement).toHaveBeenCalledTimes(1);
    });

    it('jumps to discussion on already rendered and expanded file', () => {
      const localState = state({ collapsed: false, renderIt: true });

      renderFileForDiscussionId({ rootState, state: localState, commit }, '123');

      expect(commit).not.toHaveBeenCalled();
      expect($emit).toHaveBeenCalledTimes(1);
      expect(scrollToElement).not.toHaveBeenCalled();
    });
  });

  describe('setRenderTreeList', () => {
    it('commits SET_RENDER_TREE_LIST', done => {
      testAction(
        setRenderTreeList,
        true,
        {},
        [{ type: types.SET_RENDER_TREE_LIST, payload: true }],
        [],
        done,
      );
    });

    it('sets localStorage', () => {
      spyOn(localStorage, 'setItem').and.stub();

      setRenderTreeList({ commit() {} }, true);

      expect(localStorage.setItem).toHaveBeenCalledWith('mr_diff_tree_list', true);
    });
  });

  describe('setShowWhitespace', () => {
    it('commits SET_SHOW_WHITESPACE', done => {
      testAction(
        setShowWhitespace,
        { showWhitespace: true },
        {},
        [{ type: types.SET_SHOW_WHITESPACE, payload: true }],
        [],
        done,
      );
    });

    it('sets localStorage', () => {
      spyOn(localStorage, 'setItem').and.stub();

      setShowWhitespace({ commit() {} }, { showWhitespace: true });

      expect(localStorage.setItem).toHaveBeenCalledWith('mr_show_whitespace', true);
    });

    it('calls history pushState', () => {
      spyOn(localStorage, 'setItem').and.stub();
      spyOn(window.history, 'pushState').and.stub();

      setShowWhitespace({ commit() {} }, { showWhitespace: true, pushState: true });

      expect(window.history.pushState).toHaveBeenCalled();
    });
  });

  describe('setRenderIt', () => {
    it('commits RENDER_FILE', done => {
      testAction(setRenderIt, 'file', {}, [{ type: types.RENDER_FILE, payload: 'file' }], [], done);
    });
  });

  describe('requestFullDiff', () => {
    it('commits REQUEST_FULL_DIFF', done => {
      testAction(
        requestFullDiff,
        'file',
        {},
        [{ type: types.REQUEST_FULL_DIFF, payload: 'file' }],
        [],
        done,
      );
    });
  });

  describe('receiveFullDiffSucess', () => {
    it('commits REQUEST_FULL_DIFF', done => {
      testAction(
        receiveFullDiffSucess,
        { filePath: 'test', data: 'test' },
        {},
        [{ type: types.RECEIVE_FULL_DIFF_SUCCESS, payload: { filePath: 'test', data: 'test' } }],
        [],
        done,
      );
    });
  });

  describe('receiveFullDiffError', () => {
    it('commits REQUEST_FULL_DIFF', done => {
      testAction(
        receiveFullDiffError,
        'file',
        {},
        [{ type: types.RECEIVE_FULL_DIFF_ERROR, payload: 'file' }],
        [],
        done,
      );
    });
  });

  describe('fetchFullDiff', () => {
    let mock;
    let scrollToElementSpy;

    beforeEach(() => {
      scrollToElementSpy = spyOnDependency(actions, 'scrollToElement').and.stub();

      mock = new MockAdapter(axios);
    });

    afterEach(() => {
      mock.restore();
    });

    describe('success', () => {
      beforeEach(() => {
        mock.onGet(`${gl.TEST_HOST}/context`).replyOnce(200, ['test']);
      });

      it('dispatches receiveFullDiffSucess', done => {
        testAction(
          fetchFullDiff,
          { context_lines_path: `${gl.TEST_HOST}/context`, file_path: 'test', file_hash: 'test' },
          null,
          [],
          [{ type: 'receiveFullDiffSucess', payload: { filePath: 'test', data: ['test'] } }],
          done,
        );
      });

      it('scrolls to element', done => {
        fetchFullDiff(
          { dispatch() {} },
          { context_lines_path: `${gl.TEST_HOST}/context`, file_path: 'test', file_hash: 'test' },
        )
          .then(() => {
            expect(scrollToElementSpy).toHaveBeenCalledWith('#test');

            done();
          })
          .catch(done.fail);
      });
    });

    describe('error', () => {
      beforeEach(() => {
        mock.onGet(`${gl.TEST_HOST}/context`).replyOnce(500);
      });

      it('dispatches receiveFullDiffError', done => {
        testAction(
          fetchFullDiff,
          { context_lines_path: `${gl.TEST_HOST}/context`, file_path: 'test', file_hash: 'test' },
          null,
          [],
          [{ type: 'receiveFullDiffError', payload: 'test' }],
          done,
        );
      });
    });
  });

  describe('toggleFullDiff', () => {
    let state;

    beforeEach(() => {
      state = {
        diffFiles: [{ file_path: 'test', isShowingFullFile: false }],
      };
    });

    it('dispatches fetchFullDiff when file is not expanded', done => {
      testAction(
        toggleFullDiff,
        'test',
        state,
        [],
        [
          { type: 'requestFullDiff', payload: 'test' },
          { type: 'fetchFullDiff', payload: state.diffFiles[0] },
        ],
        done,
      );
    });
  });

  describe('setFileCollapsed', () => {
    it('commits SET_FILE_COLLAPSED', done => {
      testAction(
        setFileCollapsed,
        { filePath: 'test', collapsed: true },
        null,
        [{ type: types.SET_FILE_COLLAPSED, payload: { filePath: 'test', collapsed: true } }],
        [],
        done,
      );
    });
  });
});
