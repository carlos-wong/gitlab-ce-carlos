import MockAdapter from 'axios-mock-adapter';
import testAction from 'helpers/vuex_action_helper';
import Api from '~/api';
import * as actions from '~/ci_variable_list/store/actions';
import * as types from '~/ci_variable_list/store/mutation_types';
import getInitialState from '~/ci_variable_list/store/state';
import { prepareDataForDisplay, prepareEnvironments } from '~/ci_variable_list/store/utils';
import createFlash from '~/flash';
import axios from '~/lib/utils/axios_utils';
import mockData from '../services/mock_data';

jest.mock('~/api.js');
jest.mock('~/flash.js');

describe('CI variable list store actions', () => {
  let mock;
  let state;
  const mockVariable = {
    environment_scope: '*',
    id: 63,
    key: 'test_var',
    masked: false,
    protected: false,
    value: 'test_val',
    variable_type: 'env_var',
    _destory: true,
  };
  const payloadError = new Error('Request failed with status code 500');

  beforeEach(() => {
    mock = new MockAdapter(axios);
    state = getInitialState();
    state.endpoint = '/variables';
  });

  afterEach(() => {
    mock.restore();
  });

  describe('toggleValues', () => {
    const valuesHidden = false;
    it('commits TOGGLE_VALUES mutation', () => {
      testAction(actions.toggleValues, valuesHidden, {}, [
        {
          type: types.TOGGLE_VALUES,
          payload: valuesHidden,
        },
      ]);
    });
  });

  describe('clearModal', () => {
    it('commits CLEAR_MODAL mutation', () => {
      testAction(actions.clearModal, {}, {}, [
        {
          type: types.CLEAR_MODAL,
        },
      ]);
    });
  });

  describe('resetEditing', () => {
    it('commits RESET_EDITING mutation', () => {
      testAction(
        actions.resetEditing,
        {},
        {},
        [
          {
            type: types.RESET_EDITING,
          },
        ],
        [{ type: 'fetchVariables' }],
      );
    });
  });

  describe('setVariableProtected', () => {
    it('commits SET_VARIABLE_PROTECTED mutation', () => {
      testAction(actions.setVariableProtected, {}, {}, [
        {
          type: types.SET_VARIABLE_PROTECTED,
        },
      ]);
    });
  });

  describe('deleteVariable', () => {
    it('dispatch correct actions on successful deleted variable', () => {
      mock.onPatch(state.endpoint).reply(200);

      return testAction(
        actions.deleteVariable,
        {},
        state,
        [],
        [
          { type: 'requestDeleteVariable' },
          { type: 'receiveDeleteVariableSuccess' },
          { type: 'fetchVariables' },
        ],
      );
    });

    it('should show flash error and set error in state on delete failure', async () => {
      mock.onPatch(state.endpoint).reply(500, '');

      await testAction(
        actions.deleteVariable,
        {},
        state,
        [],
        [
          { type: 'requestDeleteVariable' },
          {
            type: 'receiveDeleteVariableError',
            payload: payloadError,
          },
        ],
      );
      expect(createFlash).toHaveBeenCalled();
    });
  });

  describe('updateVariable', () => {
    it('dispatch correct actions on successful updated variable', () => {
      mock.onPatch(state.endpoint).reply(200);

      return testAction(
        actions.updateVariable,
        {},
        state,
        [],
        [
          { type: 'requestUpdateVariable' },
          { type: 'receiveUpdateVariableSuccess' },
          { type: 'fetchVariables' },
        ],
      );
    });

    it('should show flash error and set error in state on update failure', async () => {
      mock.onPatch(state.endpoint).reply(500, '');

      await testAction(
        actions.updateVariable,
        mockVariable,
        state,
        [],
        [
          { type: 'requestUpdateVariable' },
          {
            type: 'receiveUpdateVariableError',
            payload: payloadError,
          },
        ],
      );
      expect(createFlash).toHaveBeenCalled();
    });
  });

  describe('addVariable', () => {
    it('dispatch correct actions on successful added variable', () => {
      mock.onPatch(state.endpoint).reply(200);

      return testAction(
        actions.addVariable,
        {},
        state,
        [],
        [
          { type: 'requestAddVariable' },
          { type: 'receiveAddVariableSuccess' },
          { type: 'fetchVariables' },
        ],
      );
    });

    it('should show flash error and set error in state on add failure', async () => {
      mock.onPatch(state.endpoint).reply(500, '');

      await testAction(
        actions.addVariable,
        {},
        state,
        [],
        [
          { type: 'requestAddVariable' },
          {
            type: 'receiveAddVariableError',
            payload: payloadError,
          },
        ],
      );
      expect(createFlash).toHaveBeenCalled();
    });
  });

  describe('fetchVariables', () => {
    it('dispatch correct actions on fetchVariables', () => {
      mock.onGet(state.endpoint).reply(200, { variables: mockData.mockVariables });

      return testAction(
        actions.fetchVariables,
        {},
        state,
        [],
        [
          { type: 'requestVariables' },
          {
            type: 'receiveVariablesSuccess',
            payload: prepareDataForDisplay(mockData.mockVariables),
          },
        ],
      );
    });

    it('should show flash error and set error in state on fetch variables failure', async () => {
      mock.onGet(state.endpoint).reply(500);

      await testAction(actions.fetchVariables, {}, state, [], [{ type: 'requestVariables' }]);
      expect(createFlash).toHaveBeenCalledWith({
        message: 'There was an error fetching the variables.',
      });
    });
  });

  describe('fetchEnvironments', () => {
    it('dispatch correct actions on fetchEnvironments', () => {
      Api.environments = jest.fn().mockResolvedValue({ data: mockData.mockEnvironments });

      return testAction(
        actions.fetchEnvironments,
        {},
        state,
        [],
        [
          { type: 'requestEnvironments' },
          {
            type: 'receiveEnvironmentsSuccess',
            payload: prepareEnvironments(mockData.mockEnvironments),
          },
        ],
      );
    });

    it('should show flash error and set error in state on fetch environments failure', async () => {
      Api.environments = jest.fn().mockRejectedValue();

      await testAction(actions.fetchEnvironments, {}, state, [], [{ type: 'requestEnvironments' }]);

      expect(createFlash).toHaveBeenCalledWith({
        message: 'There was an error fetching the environments information.',
      });
    });
  });

  describe('Update variable values', () => {
    it('updateVariableKey', () => {
      testAction(
        actions.updateVariableKey,
        { key: mockVariable.key },
        {},
        [
          {
            type: types.UPDATE_VARIABLE_KEY,
            payload: mockVariable.key,
          },
        ],
        [],
      );
    });

    it('updateVariableValue', () => {
      testAction(
        actions.updateVariableValue,
        { secret_value: mockVariable.value },
        {},
        [
          {
            type: types.UPDATE_VARIABLE_VALUE,
            payload: mockVariable.value,
          },
        ],
        [],
      );
    });

    it('updateVariableType', () => {
      testAction(
        actions.updateVariableType,
        { variable_type: mockVariable.variable_type },
        {},
        [{ type: types.UPDATE_VARIABLE_TYPE, payload: mockVariable.variable_type }],
        [],
      );
    });

    it('updateVariableProtected', () => {
      testAction(
        actions.updateVariableProtected,
        { protected_variable: mockVariable.protected },
        {},
        [{ type: types.UPDATE_VARIABLE_PROTECTED, payload: mockVariable.protected }],
        [],
      );
    });

    it('updateVariableMasked', () => {
      testAction(
        actions.updateVariableMasked,
        { masked: mockVariable.masked },
        {},
        [{ type: types.UPDATE_VARIABLE_MASKED, payload: mockVariable.masked }],
        [],
      );
    });
  });
});
