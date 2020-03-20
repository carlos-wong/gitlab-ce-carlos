import testAction from 'helpers/vuex_action_helper';
import * as actions from '~/ide/stores/modules/pane/actions';
import * as types from '~/ide/stores/modules/pane/mutation_types';

describe('IDE pane module actions', () => {
  const TEST_VIEW = { name: 'test' };
  const TEST_VIEW_KEEP_ALIVE = { name: 'test-keep-alive', keepAlive: true };

  describe('toggleOpen', () => {
    it('dispatches open if closed', done => {
      testAction(actions.toggleOpen, TEST_VIEW, { isOpen: false }, [], [{ type: 'open' }], done);
    });

    it('dispatches close if opened', done => {
      testAction(actions.toggleOpen, TEST_VIEW, { isOpen: true }, [], [{ type: 'close' }], done);
    });
  });

  describe('open', () => {
    describe('with a view specified', () => {
      it('commits SET_OPEN and SET_CURRENT_VIEW', done => {
        testAction(
          actions.open,
          TEST_VIEW,
          {},
          [
            { type: types.SET_OPEN, payload: true },
            { type: types.SET_CURRENT_VIEW, payload: TEST_VIEW.name },
          ],
          [],
          done,
        );
      });

      it('commits KEEP_ALIVE_VIEW if keepAlive is true', done => {
        testAction(
          actions.open,
          TEST_VIEW_KEEP_ALIVE,
          {},
          [
            { type: types.SET_OPEN, payload: true },
            { type: types.SET_CURRENT_VIEW, payload: TEST_VIEW_KEEP_ALIVE.name },
            { type: types.KEEP_ALIVE_VIEW, payload: TEST_VIEW_KEEP_ALIVE.name },
          ],
          [],
          done,
        );
      });
    });

    describe('without a view specified', () => {
      it('commits SET_OPEN', done => {
        testAction(
          actions.open,
          undefined,
          {},
          [{ type: types.SET_OPEN, payload: true }],
          [],
          done,
        );
      });
    });
  });

  describe('close', () => {
    it('commits SET_OPEN', done => {
      testAction(actions.close, null, {}, [{ type: types.SET_OPEN, payload: false }], [], done);
    });
  });
});
