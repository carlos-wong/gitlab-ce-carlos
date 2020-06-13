import MockAdapter from 'axios-mock-adapter';
import { TEST_HOST } from 'spec/test_constants';
import testAction from 'helpers/vuex_action_helper';
import axios from '~/lib/utils/axios_utils';
import actions, { transformBackendBadge } from '~/badges/store/actions';
import mutationTypes from '~/badges/store/mutation_types';
import createState from '~/badges/store/state';
import { createDummyBadge, createDummyBadgeResponse } from '../dummy_badge';

describe('Badges store actions', () => {
  const dummyEndpointUrl = `${TEST_HOST}/badges/endpoint`;
  const dummyBadges = [{ ...createDummyBadge(), id: 5 }, { ...createDummyBadge(), id: 6 }];

  let axiosMock;
  let badgeId;
  let state;

  beforeEach(() => {
    axiosMock = new MockAdapter(axios);
    state = {
      ...createState(),
      apiEndpointUrl: dummyEndpointUrl,
      badges: dummyBadges,
    };
    badgeId = state.badges[0].id;
  });

  afterEach(() => {
    axiosMock.restore();
  });

  describe('requestNewBadge', () => {
    it('commits REQUEST_NEW_BADGE', done => {
      testAction(
        actions.requestNewBadge,
        null,
        state,
        [{ type: mutationTypes.REQUEST_NEW_BADGE }],
        [],
        done,
      );
    });
  });

  describe('receiveNewBadge', () => {
    it('commits RECEIVE_NEW_BADGE', done => {
      const newBadge = createDummyBadge();
      testAction(
        actions.receiveNewBadge,
        newBadge,
        state,
        [{ type: mutationTypes.RECEIVE_NEW_BADGE, payload: newBadge }],
        [],
        done,
      );
    });
  });

  describe('receiveNewBadgeError', () => {
    it('commits RECEIVE_NEW_BADGE_ERROR', done => {
      testAction(
        actions.receiveNewBadgeError,
        null,
        state,
        [{ type: mutationTypes.RECEIVE_NEW_BADGE_ERROR }],
        [],
        done,
      );
    });
  });

  describe('addBadge', () => {
    let badgeInAddForm;
    let dispatch;
    let endpointMock;

    beforeEach(() => {
      endpointMock = axiosMock.onPost(dummyEndpointUrl);
      dispatch = jest.fn();
      badgeInAddForm = createDummyBadge();
      state = {
        ...state,
        badgeInAddForm,
      };
    });

    it('dispatches requestNewBadge and receiveNewBadge for successful response', done => {
      const dummyResponse = createDummyBadgeResponse();

      endpointMock.replyOnce(req => {
        expect(req.data).toBe(
          JSON.stringify({
            name: 'TestBadge',
            image_url: badgeInAddForm.imageUrl,
            link_url: badgeInAddForm.linkUrl,
          }),
        );

        expect(dispatch.mock.calls).toEqual([['requestNewBadge']]);
        dispatch.mockClear();
        return [200, dummyResponse];
      });

      const dummyBadge = transformBackendBadge(dummyResponse);
      actions
        .addBadge({ state, dispatch })
        .then(() => {
          expect(dispatch.mock.calls).toEqual([['receiveNewBadge', dummyBadge]]);
        })
        .then(done)
        .catch(done.fail);
    });

    it('dispatches requestNewBadge and receiveNewBadgeError for error response', done => {
      endpointMock.replyOnce(req => {
        expect(req.data).toBe(
          JSON.stringify({
            name: 'TestBadge',
            image_url: badgeInAddForm.imageUrl,
            link_url: badgeInAddForm.linkUrl,
          }),
        );

        expect(dispatch.mock.calls).toEqual([['requestNewBadge']]);
        dispatch.mockClear();
        return [500, ''];
      });

      actions
        .addBadge({ state, dispatch })
        .then(() => done.fail('Expected Ajax call to fail!'))
        .catch(() => {
          expect(dispatch.mock.calls).toEqual([['receiveNewBadgeError']]);
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('requestDeleteBadge', () => {
    it('commits REQUEST_DELETE_BADGE', done => {
      testAction(
        actions.requestDeleteBadge,
        badgeId,
        state,
        [{ type: mutationTypes.REQUEST_DELETE_BADGE, payload: badgeId }],
        [],
        done,
      );
    });
  });

  describe('receiveDeleteBadge', () => {
    it('commits RECEIVE_DELETE_BADGE', done => {
      testAction(
        actions.receiveDeleteBadge,
        badgeId,
        state,
        [{ type: mutationTypes.RECEIVE_DELETE_BADGE, payload: badgeId }],
        [],
        done,
      );
    });
  });

  describe('receiveDeleteBadgeError', () => {
    it('commits RECEIVE_DELETE_BADGE_ERROR', done => {
      testAction(
        actions.receiveDeleteBadgeError,
        badgeId,
        state,
        [{ type: mutationTypes.RECEIVE_DELETE_BADGE_ERROR, payload: badgeId }],
        [],
        done,
      );
    });
  });

  describe('deleteBadge', () => {
    let dispatch;
    let endpointMock;

    beforeEach(() => {
      endpointMock = axiosMock.onDelete(`${dummyEndpointUrl}/${badgeId}`);
      dispatch = jest.fn();
    });

    it('dispatches requestDeleteBadge and receiveDeleteBadge for successful response', done => {
      endpointMock.replyOnce(() => {
        expect(dispatch.mock.calls).toEqual([['requestDeleteBadge', badgeId]]);
        dispatch.mockClear();
        return [200, ''];
      });

      actions
        .deleteBadge({ state, dispatch }, { id: badgeId })
        .then(() => {
          expect(dispatch.mock.calls).toEqual([['receiveDeleteBadge', badgeId]]);
        })
        .then(done)
        .catch(done.fail);
    });

    it('dispatches requestDeleteBadge and receiveDeleteBadgeError for error response', done => {
      endpointMock.replyOnce(() => {
        expect(dispatch.mock.calls).toEqual([['requestDeleteBadge', badgeId]]);
        dispatch.mockClear();
        return [500, ''];
      });

      actions
        .deleteBadge({ state, dispatch }, { id: badgeId })
        .then(() => done.fail('Expected Ajax call to fail!'))
        .catch(() => {
          expect(dispatch.mock.calls).toEqual([['receiveDeleteBadgeError', badgeId]]);
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('editBadge', () => {
    it('commits START_EDITING', done => {
      const dummyBadge = createDummyBadge();
      testAction(
        actions.editBadge,
        dummyBadge,
        state,
        [{ type: mutationTypes.START_EDITING, payload: dummyBadge }],
        [],
        done,
      );
    });
  });

  describe('requestLoadBadges', () => {
    it('commits REQUEST_LOAD_BADGES', done => {
      const dummyData = 'this is not real data';
      testAction(
        actions.requestLoadBadges,
        dummyData,
        state,
        [{ type: mutationTypes.REQUEST_LOAD_BADGES, payload: dummyData }],
        [],
        done,
      );
    });
  });

  describe('receiveLoadBadges', () => {
    it('commits RECEIVE_LOAD_BADGES', done => {
      const badges = dummyBadges;
      testAction(
        actions.receiveLoadBadges,
        badges,
        state,
        [{ type: mutationTypes.RECEIVE_LOAD_BADGES, payload: badges }],
        [],
        done,
      );
    });
  });

  describe('receiveLoadBadgesError', () => {
    it('commits RECEIVE_LOAD_BADGES_ERROR', done => {
      testAction(
        actions.receiveLoadBadgesError,
        null,
        state,
        [{ type: mutationTypes.RECEIVE_LOAD_BADGES_ERROR }],
        [],
        done,
      );
    });
  });

  describe('loadBadges', () => {
    let dispatch;
    let endpointMock;

    beforeEach(() => {
      endpointMock = axiosMock.onGet(dummyEndpointUrl);
      dispatch = jest.fn();
    });

    it('dispatches requestLoadBadges and receiveLoadBadges for successful response', done => {
      const dummyData = 'this is just some data';
      const dummyReponse = [
        createDummyBadgeResponse(),
        createDummyBadgeResponse(),
        createDummyBadgeResponse(),
      ];
      endpointMock.replyOnce(() => {
        expect(dispatch.mock.calls).toEqual([['requestLoadBadges', dummyData]]);
        dispatch.mockClear();
        return [200, dummyReponse];
      });

      actions
        .loadBadges({ state, dispatch }, dummyData)
        .then(() => {
          const badges = dummyReponse.map(transformBackendBadge);

          expect(dispatch.mock.calls).toEqual([['receiveLoadBadges', badges]]);
        })
        .then(done)
        .catch(done.fail);
    });

    it('dispatches requestLoadBadges and receiveLoadBadgesError for error response', done => {
      const dummyData = 'this is just some data';
      endpointMock.replyOnce(() => {
        expect(dispatch.mock.calls).toEqual([['requestLoadBadges', dummyData]]);
        dispatch.mockClear();
        return [500, ''];
      });

      actions
        .loadBadges({ state, dispatch }, dummyData)
        .then(() => done.fail('Expected Ajax call to fail!'))
        .catch(() => {
          expect(dispatch.mock.calls).toEqual([['receiveLoadBadgesError']]);
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('requestRenderedBadge', () => {
    it('commits REQUEST_RENDERED_BADGE', done => {
      testAction(
        actions.requestRenderedBadge,
        null,
        state,
        [{ type: mutationTypes.REQUEST_RENDERED_BADGE }],
        [],
        done,
      );
    });
  });

  describe('receiveRenderedBadge', () => {
    it('commits RECEIVE_RENDERED_BADGE', done => {
      const dummyBadge = createDummyBadge();
      testAction(
        actions.receiveRenderedBadge,
        dummyBadge,
        state,
        [{ type: mutationTypes.RECEIVE_RENDERED_BADGE, payload: dummyBadge }],
        [],
        done,
      );
    });
  });

  describe('receiveRenderedBadgeError', () => {
    it('commits RECEIVE_RENDERED_BADGE_ERROR', done => {
      testAction(
        actions.receiveRenderedBadgeError,
        null,
        state,
        [{ type: mutationTypes.RECEIVE_RENDERED_BADGE_ERROR }],
        [],
        done,
      );
    });
  });

  describe('renderBadge', () => {
    let dispatch;
    let endpointMock;
    let badgeInForm;

    beforeEach(() => {
      badgeInForm = createDummyBadge();
      state = {
        ...state,
        badgeInAddForm: badgeInForm,
      };
      const urlParameters = [
        `link_url=${encodeURIComponent(badgeInForm.linkUrl)}`,
        `image_url=${encodeURIComponent(badgeInForm.imageUrl)}`,
      ].join('&');
      endpointMock = axiosMock.onGet(`${dummyEndpointUrl}/render?${urlParameters}`);
      dispatch = jest.fn();
    });

    it('returns immediately if imageUrl is empty', done => {
      jest.spyOn(axios, 'get').mockImplementation(() => {});
      badgeInForm.imageUrl = '';

      actions
        .renderBadge({ state, dispatch })
        .then(() => {
          expect(axios.get).not.toHaveBeenCalled();
        })
        .then(done)
        .catch(done.fail);
    });

    it('returns immediately if linkUrl is empty', done => {
      jest.spyOn(axios, 'get').mockImplementation(() => {});
      badgeInForm.linkUrl = '';

      actions
        .renderBadge({ state, dispatch })
        .then(() => {
          expect(axios.get).not.toHaveBeenCalled();
        })
        .then(done)
        .catch(done.fail);
    });

    it('escapes user input', done => {
      jest
        .spyOn(axios, 'get')
        .mockImplementation(() => Promise.resolve({ data: createDummyBadgeResponse() }));
      badgeInForm.imageUrl = '&make-sandwich=true';
      badgeInForm.linkUrl = '<script>I am dangerous!</script>';

      actions
        .renderBadge({ state, dispatch })
        .then(() => {
          expect(axios.get.mock.calls.length).toBe(1);
          const url = axios.get.mock.calls[0][0];

          expect(url).toMatch(new RegExp(`^${dummyEndpointUrl}/render?`));
          expect(url).toMatch(
            new RegExp('\\?link_url=%3Cscript%3EI%20am%20dangerous!%3C%2Fscript%3E&'),
          );
          expect(url).toMatch(new RegExp('&image_url=%26make-sandwich%3Dtrue$'));
        })
        .then(done)
        .catch(done.fail);
    });

    it('dispatches requestRenderedBadge and receiveRenderedBadge for successful response', done => {
      const dummyReponse = createDummyBadgeResponse();
      endpointMock.replyOnce(() => {
        expect(dispatch.mock.calls).toEqual([['requestRenderedBadge']]);
        dispatch.mockClear();
        return [200, dummyReponse];
      });

      actions
        .renderBadge({ state, dispatch })
        .then(() => {
          const renderedBadge = transformBackendBadge(dummyReponse);

          expect(dispatch.mock.calls).toEqual([['receiveRenderedBadge', renderedBadge]]);
        })
        .then(done)
        .catch(done.fail);
    });

    it('dispatches requestRenderedBadge and receiveRenderedBadgeError for error response', done => {
      endpointMock.replyOnce(() => {
        expect(dispatch.mock.calls).toEqual([['requestRenderedBadge']]);
        dispatch.mockClear();
        return [500, ''];
      });

      actions
        .renderBadge({ state, dispatch })
        .then(() => done.fail('Expected Ajax call to fail!'))
        .catch(() => {
          expect(dispatch.mock.calls).toEqual([['receiveRenderedBadgeError']]);
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('requestUpdatedBadge', () => {
    it('commits REQUEST_UPDATED_BADGE', done => {
      testAction(
        actions.requestUpdatedBadge,
        null,
        state,
        [{ type: mutationTypes.REQUEST_UPDATED_BADGE }],
        [],
        done,
      );
    });
  });

  describe('receiveUpdatedBadge', () => {
    it('commits RECEIVE_UPDATED_BADGE', done => {
      const updatedBadge = createDummyBadge();
      testAction(
        actions.receiveUpdatedBadge,
        updatedBadge,
        state,
        [{ type: mutationTypes.RECEIVE_UPDATED_BADGE, payload: updatedBadge }],
        [],
        done,
      );
    });
  });

  describe('receiveUpdatedBadgeError', () => {
    it('commits RECEIVE_UPDATED_BADGE_ERROR', done => {
      testAction(
        actions.receiveUpdatedBadgeError,
        null,
        state,
        [{ type: mutationTypes.RECEIVE_UPDATED_BADGE_ERROR }],
        [],
        done,
      );
    });
  });

  describe('saveBadge', () => {
    let badgeInEditForm;
    let dispatch;
    let endpointMock;

    beforeEach(() => {
      badgeInEditForm = createDummyBadge();
      state = {
        ...state,
        badgeInEditForm,
      };
      endpointMock = axiosMock.onPut(`${dummyEndpointUrl}/${badgeInEditForm.id}`);
      dispatch = jest.fn();
    });

    it('dispatches requestUpdatedBadge and receiveUpdatedBadge for successful response', done => {
      const dummyResponse = createDummyBadgeResponse();

      endpointMock.replyOnce(req => {
        expect(req.data).toBe(
          JSON.stringify({
            name: 'TestBadge',
            image_url: badgeInEditForm.imageUrl,
            link_url: badgeInEditForm.linkUrl,
          }),
        );

        expect(dispatch.mock.calls).toEqual([['requestUpdatedBadge']]);
        dispatch.mockClear();
        return [200, dummyResponse];
      });

      const updatedBadge = transformBackendBadge(dummyResponse);
      actions
        .saveBadge({ state, dispatch })
        .then(() => {
          expect(dispatch.mock.calls).toEqual([['receiveUpdatedBadge', updatedBadge]]);
        })
        .then(done)
        .catch(done.fail);
    });

    it('dispatches requestUpdatedBadge and receiveUpdatedBadgeError for error response', done => {
      endpointMock.replyOnce(req => {
        expect(req.data).toBe(
          JSON.stringify({
            name: 'TestBadge',
            image_url: badgeInEditForm.imageUrl,
            link_url: badgeInEditForm.linkUrl,
          }),
        );

        expect(dispatch.mock.calls).toEqual([['requestUpdatedBadge']]);
        dispatch.mockClear();
        return [500, ''];
      });

      actions
        .saveBadge({ state, dispatch })
        .then(() => done.fail('Expected Ajax call to fail!'))
        .catch(() => {
          expect(dispatch.mock.calls).toEqual([['receiveUpdatedBadgeError']]);
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('stopEditing', () => {
    it('commits STOP_EDITING', done => {
      testAction(
        actions.stopEditing,
        null,
        state,
        [{ type: mutationTypes.STOP_EDITING }],
        [],
        done,
      );
    });
  });

  describe('updateBadgeInForm', () => {
    it('commits UPDATE_BADGE_IN_FORM', done => {
      const dummyBadge = createDummyBadge();
      testAction(
        actions.updateBadgeInForm,
        dummyBadge,
        state,
        [{ type: mutationTypes.UPDATE_BADGE_IN_FORM, payload: dummyBadge }],
        [],
        done,
      );
    });

    describe('updateBadgeInModal', () => {
      it('commits UPDATE_BADGE_IN_MODAL', done => {
        const dummyBadge = createDummyBadge();
        testAction(
          actions.updateBadgeInModal,
          dummyBadge,
          state,
          [{ type: mutationTypes.UPDATE_BADGE_IN_MODAL, payload: dummyBadge }],
          [],
          done,
        );
      });
    });
  });
});
