import flash from '~/flash';
import { __ } from '~/locale';
import axios from '~/lib/utils/axios_utils';
import * as types from './mutation_types';

export const setInitialState = ({ commit }, props) => commit(types.SET_INITIAL_STATE, props);

export const toggleDropdownButton = ({ commit }) => commit(types.TOGGLE_DROPDOWN_BUTTON);
export const toggleDropdownContents = ({ commit }) => commit(types.TOGGLE_DROPDOWN_CONTENTS);

export const toggleDropdownContentsCreateView = ({ commit }) =>
  commit(types.TOGGLE_DROPDOWN_CONTENTS_CREATE_VIEW);

export const requestLabels = ({ commit }) => commit(types.REQUEST_LABELS);
export const receiveLabelsSuccess = ({ commit }, labels) =>
  commit(types.RECEIVE_SET_LABELS_SUCCESS, labels);
export const receiveLabelsFailure = ({ commit }) => {
  commit(types.RECEIVE_SET_LABELS_FAILURE);
  flash(__('Error fetching labels.'));
};
export const fetchLabels = ({ state, dispatch }) => {
  dispatch('requestLabels');
  axios
    .get(state.labelsFetchPath)
    .then(({ data }) => {
      dispatch('receiveLabelsSuccess', data);
    })
    .catch(() => dispatch('receiveLabelsFailure'));
};

export const requestCreateLabel = ({ commit }) => commit(types.REQUEST_CREATE_LABEL);
export const receiveCreateLabelSuccess = ({ commit }) => commit(types.RECEIVE_CREATE_LABEL_SUCCESS);
export const receiveCreateLabelFailure = ({ commit }) => {
  commit(types.RECEIVE_CREATE_LABEL_FAILURE);
  flash(__('Error creating label.'));
};
export const createLabel = ({ state, dispatch }, label) => {
  dispatch('requestCreateLabel');
  axios
    .post(state.labelsManagePath, {
      label,
    })
    .then(({ data }) => {
      if (data.id) {
        dispatch('receiveCreateLabelSuccess');
        dispatch('toggleDropdownContentsCreateView');
      } else {
        // eslint-disable-next-line @gitlab/i18n/no-non-i18n-strings
        throw new Error('Error Creating Label');
      }
    })
    .catch(() => {
      dispatch('receiveCreateLabelFailure');
    });
};

export const updateSelectedLabels = ({ commit }, labels) =>
  commit(types.UPDATE_SELECTED_LABELS, { labels });

// prevent babel-plugin-rewire from generating an invalid default during karma tests
export default () => {};
