import * as types from './mutation_types';
import axios from '~/lib/utils/axios_utils';
import Api from '~/api';
import createFlash from '~/flash';
import { __ } from '~/locale';
import { prepareDataForApi, prepareDataForDisplay, prepareEnvironments } from './utils';

export const toggleValues = ({ commit }, valueState) => {
  commit(types.TOGGLE_VALUES, valueState);
};

export const clearModal = ({ commit }) => {
  commit(types.CLEAR_MODAL);
};

export const resetEditing = ({ commit, dispatch }) => {
  // fetch variables again if modal is being edited and then hidden
  // without saving changes, to cover use case of reactivity in the table
  dispatch('fetchVariables');
  commit(types.RESET_EDITING);
};

export const requestAddVariable = ({ commit }) => {
  commit(types.REQUEST_ADD_VARIABLE);
};

export const receiveAddVariableSuccess = ({ commit }) => {
  commit(types.RECEIVE_ADD_VARIABLE_SUCCESS);
};

export const receiveAddVariableError = ({ commit }, error) => {
  commit(types.RECEIVE_ADD_VARIABLE_ERROR, error);
};

export const addVariable = ({ state, dispatch }) => {
  dispatch('requestAddVariable');

  return axios
    .patch(state.endpoint, {
      variables_attributes: [prepareDataForApi(state.variable)],
    })
    .then(() => {
      dispatch('receiveAddVariableSuccess');
      dispatch('fetchVariables');
    })
    .catch(error => {
      createFlash(error.response.data[0]);
      dispatch('receiveAddVariableError', error);
    });
};

export const requestUpdateVariable = ({ commit }) => {
  commit(types.REQUEST_UPDATE_VARIABLE);
};

export const receiveUpdateVariableSuccess = ({ commit }) => {
  commit(types.RECEIVE_UPDATE_VARIABLE_SUCCESS);
};

export const receiveUpdateVariableError = ({ commit }, error) => {
  commit(types.RECEIVE_UPDATE_VARIABLE_ERROR, error);
};

export const updateVariable = ({ state, dispatch }, variable) => {
  dispatch('requestUpdateVariable');

  const updatedVariable = prepareDataForApi(variable);
  updatedVariable.secrect_value = updateVariable.value;

  return axios
    .patch(state.endpoint, { variables_attributes: [updatedVariable] })
    .then(() => {
      dispatch('receiveUpdateVariableSuccess');
      dispatch('fetchVariables');
    })
    .catch(error => {
      createFlash(error.response.data[0]);
      dispatch('receiveUpdateVariableError', error);
    });
};

export const editVariable = ({ commit }, variable) => {
  const variableToEdit = variable;
  variableToEdit.secret_value = variableToEdit.value;
  commit(types.VARIABLE_BEING_EDITED, variableToEdit);
};

export const requestVariables = ({ commit }) => {
  commit(types.REQUEST_VARIABLES);
};
export const receiveVariablesSuccess = ({ commit }, variables) => {
  commit(types.RECEIVE_VARIABLES_SUCCESS, variables);
};

export const fetchVariables = ({ dispatch, state }) => {
  dispatch('requestVariables');

  return axios
    .get(state.endpoint)
    .then(({ data }) => {
      dispatch('receiveVariablesSuccess', prepareDataForDisplay(data.variables));
    })
    .catch(() => {
      createFlash(__('There was an error fetching the variables.'));
    });
};

export const requestDeleteVariable = ({ commit }) => {
  commit(types.REQUEST_DELETE_VARIABLE);
};

export const receiveDeleteVariableSuccess = ({ commit }) => {
  commit(types.RECEIVE_DELETE_VARIABLE_SUCCESS);
};

export const receiveDeleteVariableError = ({ commit }, error) => {
  commit(types.RECEIVE_DELETE_VARIABLE_ERROR, error);
};

export const deleteVariable = ({ dispatch, state }, variable) => {
  dispatch('requestDeleteVariable');

  const destroy = true;

  return axios
    .patch(state.endpoint, { variables_attributes: [prepareDataForApi(variable, destroy)] })
    .then(() => {
      dispatch('receiveDeleteVariableSuccess');
      dispatch('fetchVariables');
    })
    .catch(error => {
      createFlash(error.response.data[0]);
      dispatch('receiveDeleteVariableError', error);
    });
};

export const requestEnvironments = ({ commit }) => {
  commit(types.REQUEST_ENVIRONMENTS);
};

export const receiveEnvironmentsSuccess = ({ commit }, environments) => {
  commit(types.RECEIVE_ENVIRONMENTS_SUCCESS, environments);
};

export const fetchEnvironments = ({ dispatch, state }) => {
  dispatch('requestEnvironments');

  return Api.environments(state.projectId)
    .then(res => {
      dispatch('receiveEnvironmentsSuccess', prepareEnvironments(res.data));
    })
    .catch(() => {
      createFlash(__('There was an error fetching the environments information.'));
    });
};
