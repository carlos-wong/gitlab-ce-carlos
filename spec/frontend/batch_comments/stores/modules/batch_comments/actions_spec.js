import MockAdapter from 'axios-mock-adapter';
import { TEST_HOST } from 'helpers/test_constants';
import testAction from 'helpers/vuex_action_helper';
import service from '~/batch_comments/services/drafts_service';
import * as actions from '~/batch_comments/stores/modules/batch_comments/actions';
import axios from '~/lib/utils/axios_utils';

describe('Batch comments store actions', () => {
  let res = {};
  let mock;

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    res = {};
    mock.restore();
  });

  describe('saveDraft', () => {
    it('dispatches saveNote on root', () => {
      const dispatch = jest.fn();

      actions.saveDraft({ dispatch }, { id: 1 });

      expect(dispatch).toHaveBeenCalledWith('saveNote', { id: 1, isDraft: true }, { root: true });
    });
  });

  describe('addDraftToDiscussion', () => {
    it('commits ADD_NEW_DRAFT if no errors returned', () => {
      res = { id: 1 };
      mock.onAny().reply(200, res);

      return testAction(
        actions.addDraftToDiscussion,
        { endpoint: TEST_HOST, data: 'test' },
        null,
        [{ type: 'ADD_NEW_DRAFT', payload: res }],
        [],
      );
    });

    it('does not commit ADD_NEW_DRAFT if errors returned', () => {
      mock.onAny().reply(500);

      return testAction(
        actions.addDraftToDiscussion,
        { endpoint: TEST_HOST, data: 'test' },
        null,
        [],
        [],
      );
    });
  });

  describe('createNewDraft', () => {
    it('commits ADD_NEW_DRAFT if no errors returned', () => {
      res = { id: 1 };
      mock.onAny().reply(200, res);

      return testAction(
        actions.createNewDraft,
        { endpoint: TEST_HOST, data: 'test' },
        null,
        [{ type: 'ADD_NEW_DRAFT', payload: res }],
        [],
      );
    });

    it('does not commit ADD_NEW_DRAFT if errors returned', () => {
      mock.onAny().reply(500);

      return testAction(
        actions.createNewDraft,
        { endpoint: TEST_HOST, data: 'test' },
        null,
        [],
        [],
      );
    });
  });

  describe('deleteDraft', () => {
    let getters;

    beforeEach(() => {
      getters = {
        getNotesData: {
          draftsDiscardPath: TEST_HOST,
        },
      };
    });

    it('commits DELETE_DRAFT if no errors returned', () => {
      const commit = jest.fn();
      const context = {
        getters,
        commit,
      };
      res = { id: 1 };
      mock.onAny().reply(200);

      return actions.deleteDraft(context, { id: 1 }).then(() => {
        expect(commit).toHaveBeenCalledWith('DELETE_DRAFT', 1);
      });
    });

    it('does not commit DELETE_DRAFT if errors returned', () => {
      const commit = jest.fn();
      const context = {
        getters,
        commit,
      };
      mock.onAny().reply(500);

      return actions.deleteDraft(context, { id: 1 }).then(() => {
        expect(commit).not.toHaveBeenCalledWith('DELETE_DRAFT', 1);
      });
    });
  });

  describe('fetchDrafts', () => {
    let getters;

    beforeEach(() => {
      getters = {
        getNotesData: {
          draftsPath: TEST_HOST,
        },
      };
    });

    it('commits SET_BATCH_COMMENTS_DRAFTS with returned data', () => {
      const commit = jest.fn();
      const dispatch = jest.fn();
      const context = {
        getters,
        commit,
        dispatch,
        state: {
          drafts: [{ line_code: '123' }, { line_code: null, discussion_id: '1' }],
        },
      };
      res = { id: 1 };
      mock.onAny().reply(200, res);

      return actions.fetchDrafts(context).then(() => {
        expect(commit).toHaveBeenCalledWith('SET_BATCH_COMMENTS_DRAFTS', { id: 1 });
        expect(dispatch).toHaveBeenCalledWith('convertToDiscussion', '1', { root: true });
      });
    });
  });

  describe('publishReview', () => {
    let dispatch;
    let commit;
    let getters;
    let rootGetters;

    beforeEach(() => {
      dispatch = jest.fn();
      commit = jest.fn();
      getters = {
        getNotesData: { draftsPublishPath: TEST_HOST, discussionsPath: TEST_HOST },
      };
      rootGetters = { discussionsStructuredByLineCode: 'discussions' };
    });

    it('dispatches actions & commits', () => {
      mock.onAny().reply(200);

      return actions.publishReview({ dispatch, commit, getters, rootGetters }).then(() => {
        expect(commit.mock.calls[0]).toEqual(['REQUEST_PUBLISH_REVIEW']);
        expect(commit.mock.calls[1]).toEqual(['RECEIVE_PUBLISH_REVIEW_SUCCESS']);

        expect(dispatch.mock.calls[0]).toEqual(['updateDiscussionsAfterPublish']);
      });
    });

    it('calls service with notes data', () => {
      jest.spyOn(axios, 'post');

      return actions
        .publishReview({ dispatch, commit, getters, rootGetters }, { note: 'test' })
        .then(() => {
          expect(axios.post.mock.calls[0]).toEqual(['http://test.host', { note: 'test' }]);
        });
    });

    it('dispatches error commits', () => {
      mock.onAny().reply(500);

      return actions.publishReview({ dispatch, commit, getters, rootGetters }).then(() => {
        expect(commit.mock.calls[0]).toEqual(['REQUEST_PUBLISH_REVIEW']);
        expect(commit.mock.calls[1]).toEqual(['RECEIVE_PUBLISH_REVIEW_ERROR']);
      });
    });
  });

  describe('updateDraft', () => {
    let getters;
    service.update = jest.fn();
    service.update.mockResolvedValue({ data: { id: 1 } });

    const commit = jest.fn();
    let context;
    let params;

    beforeEach(() => {
      getters = {
        getNotesData: {
          draftsPath: TEST_HOST,
        },
      };

      context = {
        getters,
        commit,
      };
      res = { id: 1 };
      mock.onAny().reply(200, res);
      params = { note: { id: 1 }, noteText: 'test' };
    });

    afterEach(() => jest.clearAllMocks());

    it('commits RECEIVE_DRAFT_UPDATE_SUCCESS with returned data', () => {
      return actions.updateDraft(context, { ...params, callback() {} }).then(() => {
        expect(commit).toHaveBeenCalledWith('RECEIVE_DRAFT_UPDATE_SUCCESS', { id: 1 });
      });
    });

    it('calls passed callback', () => {
      const callback = jest.fn();
      return actions.updateDraft(context, { ...params, callback }).then(() => {
        expect(callback).toHaveBeenCalled();
      });
    });

    it('does not stringify empty position', () => {
      return actions.updateDraft(context, { ...params, position: {}, callback() {} }).then(() => {
        expect(service.update.mock.calls[0][1].position).toBeUndefined();
      });
    });

    it('stringifies a non-empty position', () => {
      const position = { test: true };
      const expectation = JSON.stringify(position);
      return actions.updateDraft(context, { ...params, position, callback() {} }).then(() => {
        expect(service.update.mock.calls[0][1].position).toBe(expectation);
      });
    });
  });

  describe('expandAllDiscussions', () => {
    it('dispatches expandDiscussion for all drafts', () => {
      const state = {
        drafts: [
          {
            discussion_id: '1',
          },
        ],
      };

      return testAction(
        actions.expandAllDiscussions,
        null,
        state,
        [],
        [
          {
            type: 'expandDiscussion',
            payload: { discussionId: '1' },
          },
        ],
      );
    });
  });

  describe('scrollToDraft', () => {
    beforeEach(() => {
      window.mrTabs = {
        currentAction: 'notes',
        tabShown: jest.fn(),
      };
    });

    it('scrolls to draft item', () => {
      const dispatch = jest.fn();
      const rootGetters = {
        getDiscussion: () => ({
          id: '1',
          diff_discussion: true,
        }),
      };
      const draft = {
        discussion_id: '1',
        id: '2',
        file_path: 'lib/example.js',
      };

      actions.scrollToDraft({ dispatch, rootGetters }, draft);

      expect(dispatch.mock.calls).toEqual([
        [
          'diffs/setFileCollapsedAutomatically',
          { filePath: draft.file_path, collapsed: false },
          { root: true },
        ],
        ['expandDiscussion', { discussionId: '1' }, { root: true }],
      ]);

      expect(window.mrTabs.tabShown).toHaveBeenCalledWith('diffs');
    });
  });
});
