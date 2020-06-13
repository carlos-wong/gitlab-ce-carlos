import * as types from './mutation_types';

export default {
  [types.SET_INITIAL_STATE](state, props) {
    Object.assign(state, { ...props });
  },

  [types.TOGGLE_DROPDOWN_BUTTON](state) {
    state.showDropdownButton = !state.showDropdownButton;
  },

  [types.TOGGLE_DROPDOWN_CONTENTS](state) {
    if (!state.dropdownOnly) {
      state.showDropdownButton = !state.showDropdownButton;
    }
    state.showDropdownContents = !state.showDropdownContents;
    // Ensure that Create View is hidden by default
    // when dropdown contents are revealed.
    if (state.showDropdownContents) {
      state.showDropdownContentsCreateView = false;
    }
  },

  [types.TOGGLE_DROPDOWN_CONTENTS_CREATE_VIEW](state) {
    state.showDropdownContentsCreateView = !state.showDropdownContentsCreateView;
  },

  [types.REQUEST_LABELS](state) {
    state.labelsFetchInProgress = true;
  },
  [types.RECEIVE_SET_LABELS_SUCCESS](state, labels) {
    // Iterate over every label and add a `set` prop
    // to determine whether it is already a part of
    // selectedLabels array.
    const selectedLabelIds = state.selectedLabels.map(label => label.id);
    state.labelsFetchInProgress = false;
    state.labels = labels.reduce((allLabels, label) => {
      allLabels.push({
        ...label,
        set: selectedLabelIds.includes(label.id),
      });
      return allLabels;
    }, []);
  },
  [types.RECEIVE_SET_LABELS_FAILURE](state) {
    state.labelsFetchInProgress = false;
  },

  [types.REQUEST_CREATE_LABEL](state) {
    state.labelCreateInProgress = true;
  },
  [types.RECEIVE_CREATE_LABEL_SUCCESS](state) {
    state.labelCreateInProgress = false;
  },
  [types.RECEIVE_CREATE_LABEL_FAILURE](state) {
    state.labelCreateInProgress = false;
  },

  [types.UPDATE_SELECTED_LABELS](state, { labels }) {
    // Iterate over all the labels and update
    // `set` prop value to represent their current state.
    const labelIds = labels.map(label => label.id);
    state.labels = state.labels.reduce((allLabels, label) => {
      if (labelIds.includes(label.id)) {
        allLabels.push({
          ...label,
          touched: true,
          set: !label.set,
        });
      } else {
        allLabels.push(label);
      }
      return allLabels;
    }, []);
  },
};
