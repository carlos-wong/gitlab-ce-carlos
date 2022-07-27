import * as Sentry from '@sentry/browser';
import MockAdapter from 'axios-mock-adapter';
import testAction from 'helpers/vuex_action_helper';
import * as actions from '~/emoji/awards_app/store/actions';
import axios from '~/lib/utils/axios_utils';

jest.mock('@sentry/browser');
jest.mock('~/vue_shared/plugins/global_toast');

describe('Awards app actions', () => {
  describe('setInitialData', () => {
    it('commits SET_INITIAL_DATA', async () => {
      await testAction(
        actions.setInitialData,
        { path: 'https://gitlab.com' },
        {},
        [{ type: 'SET_INITIAL_DATA', payload: { path: 'https://gitlab.com' } }],
        [],
      );
    });
  });

  describe('fetchAwards', () => {
    let mock;

    beforeEach(() => {
      mock = new MockAdapter(axios);
    });

    afterEach(() => {
      mock.restore();
    });

    describe('success', () => {
      describe.each`
        relativeRootUrl
        ${null}
        ${'/gitlab'}
      `('with relative_root_url as $relativeRootUrl', ({ relativeRootUrl }) => {
        beforeEach(() => {
          window.gon = { relative_url_root: relativeRootUrl };
          mock
            .onGet(`${relativeRootUrl || ''}/awards`, { params: { per_page: 100, page: '1' } })
            .reply(200, ['thumbsup'], { 'x-next-page': '2' });
          mock
            .onGet(`${relativeRootUrl || ''}/awards`, { params: { per_page: 100, page: '2' } })
            .reply(200, ['thumbsdown']);
        });

        it('commits FETCH_AWARDS_SUCCESS', async () => {
          await testAction(
            actions.fetchAwards,
            '1',
            { path: '/awards' },
            [{ type: 'FETCH_AWARDS_SUCCESS', payload: ['thumbsup'] }],
            [{ type: 'fetchAwards', payload: '2' }],
          );
        });
      });
    });

    describe('error', () => {
      beforeEach(() => {
        mock.onGet('/awards').reply(500);
      });

      it('calls Sentry.captureException', async () => {
        await testAction(actions.fetchAwards, null, { path: '/awards' }, [], [], () => {
          expect(Sentry.captureException).toHaveBeenCalled();
        });
      });
    });
  });

  describe('toggleAward', () => {
    let mock;

    const optimisticAwardId = Number.MAX_SAFE_INTEGER - 1;
    const makeOptimisticAddMutation = (
      id = optimisticAwardId,
      name = null,
      userId = window.gon.current_user_id,
    ) => ({
      type: 'ADD_NEW_AWARD',
      payload: {
        id,
        name,
        user: {
          id: userId,
        },
      },
    });
    const makeOptimisticRemoveMutation = (id = optimisticAwardId) => ({
      type: 'REMOVE_AWARD',
      payload: id,
    });

    beforeEach(() => {
      mock = new MockAdapter(axios);
    });

    afterEach(() => {
      mock.restore();
    });

    describe.each`
      relativeRootUrl
      ${null}
      ${'/gitlab'}
    `('with relative_root_url as $relativeRootUrl', ({ relativeRootUrl }) => {
      beforeEach(() => {
        window.gon = { relative_url_root: relativeRootUrl };
      });

      describe('adding new award', () => {
        describe('success', () => {
          beforeEach(() => {
            mock.onPost(`${relativeRootUrl || ''}/awards`).reply(200, { id: 1 });
          });

          it('adds an optimistic award, removes it, and then commits ADD_NEW_AWARD', async () => {
            testAction(actions.toggleAward, null, { path: '/awards', awards: [] }, [
              makeOptimisticAddMutation(),
              makeOptimisticRemoveMutation(),
              { type: 'ADD_NEW_AWARD', payload: { id: 1 } },
            ]);
          });
        });

        describe('error', () => {
          beforeEach(() => {
            mock.onPost(`${relativeRootUrl || ''}/awards`).reply(500);
          });

          it('calls Sentry.captureException', async () => {
            await testAction(
              actions.toggleAward,
              null,
              { path: '/awards', awards: [] },
              [makeOptimisticAddMutation(), makeOptimisticRemoveMutation()],
              [],
              () => {
                expect(Sentry.captureException).toHaveBeenCalled();
              },
            );
          });
        });
      });

      describe('removing an award', () => {
        const mockData = { id: 1, name: 'thumbsup', user: { id: 1 } };

        describe('success', () => {
          beforeEach(() => {
            mock.onDelete(`${relativeRootUrl || ''}/awards/1`).reply(200);
          });

          it('commits REMOVE_AWARD', async () => {
            testAction(
              actions.toggleAward,
              'thumbsup',
              {
                path: '/awards',
                currentUserId: 1,
                awards: [mockData],
              },
              [{ type: 'REMOVE_AWARD', payload: 1 }],
            );
          });
        });

        describe('error', () => {
          const currentUserId = 1;
          const name = 'thumbsup';

          beforeEach(() => {
            mock.onDelete(`${relativeRootUrl || ''}/awards/1`).reply(500);
          });

          it('calls Sentry.captureException', async () => {
            await testAction(
              actions.toggleAward,
              name,
              {
                path: '/awards',
                currentUserId,
                awards: [mockData],
              },
              [makeOptimisticRemoveMutation(1), makeOptimisticAddMutation(1, name, currentUserId)],
              [],
              () => {
                expect(Sentry.captureException).toHaveBeenCalled();
              },
            );
          });
        });
      });
    });
  });
});
