import MockAdapter from 'axios-mock-adapter';
import testAction from 'helpers/vuex_action_helper';
import actions from '~/code_navigation/store/actions';
import { setCurrentHoverElement, addInteractionClass } from '~/code_navigation/utils';
import axios from '~/lib/utils/axios_utils';

jest.mock('~/code_navigation/utils');

describe('Code navigation actions', () => {
  const wrapTextNodes = true;

  describe('setInitialData', () => {
    it('commits SET_INITIAL_DATA', () => {
      return testAction(
        actions.setInitialData,
        { projectPath: 'test', wrapTextNodes },
        {},
        [{ type: 'SET_INITIAL_DATA', payload: { projectPath: 'test', wrapTextNodes } }],
        [],
      );
    });
  });

  describe('requestDataError', () => {
    it('commits REQUEST_DATA_ERROR', () =>
      testAction(actions.requestDataError, null, {}, [{ type: 'REQUEST_DATA_ERROR' }], []));
  });

  describe('fetchData', () => {
    let mock;

    const codeNavigationPath =
      'gitlab-org/gitlab-shell/-/jobs/1114/artifacts/raw/lsif/cmd/check/main.go.json';
    const state = { blobs: [{ path: 'index.js', codeNavigationPath }], wrapTextNodes };

    beforeEach(() => {
      window.gon = { api_version: '1' };
      mock = new MockAdapter(axios);
    });

    afterEach(() => {
      mock.restore();
    });

    describe('success', () => {
      beforeEach(() => {
        mock.onGet(codeNavigationPath).replyOnce(200, [
          {
            start_line: 0,
            start_char: 0,
            hover: { value: '123' },
          },
          {
            start_line: 1,
            start_char: 0,
            hover: null,
          },
        ]);
      });

      it('commits REQUEST_DATA_SUCCESS with normalized data', () => {
        return testAction(
          actions.fetchData,
          null,
          state,
          [
            { type: 'REQUEST_DATA' },
            {
              type: 'REQUEST_DATA_SUCCESS',
              payload: {
                path: 'index.js',
                normalizedData: {
                  '0:0': {
                    definitionLineNumber: 0,
                    start_line: 0,
                    start_char: 0,
                    hover: { value: '123' },
                  },
                },
              },
            },
          ],
          [],
        );
      });

      it('calls addInteractionClass with data', () => {
        return testAction(
          actions.fetchData,
          null,
          state,
          [
            { type: 'REQUEST_DATA' },
            {
              type: 'REQUEST_DATA_SUCCESS',
              payload: {
                path: 'index.js',
                normalizedData: {
                  '0:0': {
                    definitionLineNumber: 0,
                    start_line: 0,
                    start_char: 0,
                    hover: { value: '123' },
                  },
                },
              },
            },
          ],
          [],
        ).then(() => {
          expect(addInteractionClass).toHaveBeenCalledWith({
            path: 'index.js',
            d: {
              start_line: 0,
              start_char: 0,
              hover: { value: '123' },
            },
            wrapTextNodes,
          });
        });
      });
    });

    describe('error', () => {
      beforeEach(() => {
        mock.onGet(codeNavigationPath).replyOnce(500);
      });

      it('dispatches requestDataError', () => {
        return testAction(
          actions.fetchData,
          null,
          state,
          [{ type: 'REQUEST_DATA' }],
          [{ type: 'requestDataError' }],
        );
      });
    });
  });

  describe('showBlobInteractionZones', () => {
    it('calls addInteractionClass with data for a path', () => {
      const state = {
        data: {
          'index.js': { '0:0': 'test', '1:1': 'console.log' },
        },
        wrapTextNodes,
      };

      actions.showBlobInteractionZones({ state }, 'index.js');

      expect(addInteractionClass).toHaveBeenCalled();
      expect(addInteractionClass.mock.calls.length).toBe(2);
      expect(addInteractionClass.mock.calls[0]).toEqual([
        { path: 'index.js', d: 'test', wrapTextNodes },
      ]);
      expect(addInteractionClass.mock.calls[1]).toEqual([
        { path: 'index.js', d: 'console.log', wrapTextNodes },
      ]);
    });

    it('does not call addInteractionClass when no data exists', () => {
      const state = {
        data: null,
      };

      actions.showBlobInteractionZones({ state }, 'index.js');

      expect(addInteractionClass).not.toHaveBeenCalled();
    });
  });

  describe('showDefinition', () => {
    let target;

    beforeEach(() => {
      setFixtures(
        '<div data-path="index.js"><div class="line"><div class="js-test"></div></div></div>',
      );
      target = document.querySelector('.js-test');
    });

    it('returns early when no data exists', () => {
      return testAction(actions.showDefinition, { target }, {}, [], []);
    });

    it('commits SET_CURRENT_DEFINITION when target is not code navitation element', () => {
      return testAction(actions.showDefinition, { target }, { data: {} }, [], []);
    });

    it('commits SET_CURRENT_DEFINITION with LSIF data', () => {
      target.classList.add('js-code-navigation');
      target.setAttribute('data-line-index', '0');
      target.setAttribute('data-char-index', '0');

      return testAction(
        actions.showDefinition,
        { target },
        { data: { 'index.js': { '0:0': { hover: 'test' } } } },
        [
          {
            type: 'SET_CURRENT_DEFINITION',
            payload: {
              blobPath: 'index.js',
              definition: { hover: 'test' },
              position: { height: 0, x: 0, y: 0, lineIndex: 0 },
            },
          },
        ],
        [],
      );
    });

    it('adds hll class to target element', () => {
      target.classList.add('js-code-navigation');
      target.setAttribute('data-line-index', '0');
      target.setAttribute('data-char-index', '0');

      return testAction(
        actions.showDefinition,
        { target },
        { data: { 'index.js': { '0:0': { hover: 'test' } } } },
        [
          {
            type: 'SET_CURRENT_DEFINITION',
            payload: {
              blobPath: 'index.js',
              definition: { hover: 'test' },
              position: { height: 0, x: 0, y: 0, lineIndex: 0 },
            },
          },
        ],
        [],
      ).then(() => {
        expect(target.classList).toContain('hll');
      });
    });

    it('caches current target element', () => {
      target.classList.add('js-code-navigation');
      target.setAttribute('data-line-index', '0');
      target.setAttribute('data-char-index', '0');

      return testAction(
        actions.showDefinition,
        { target },
        { data: { 'index.js': { '0:0': { hover: 'test' } } } },
        [
          {
            type: 'SET_CURRENT_DEFINITION',
            payload: {
              blobPath: 'index.js',
              definition: { hover: 'test' },
              position: { height: 0, x: 0, y: 0, lineIndex: 0 },
            },
          },
        ],
        [],
      ).then(() => {
        expect(setCurrentHoverElement).toHaveBeenCalledWith(target);
      });
    });
  });
});
