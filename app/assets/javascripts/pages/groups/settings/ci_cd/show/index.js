import initSettingsPanels from '~/settings_panels';
import AjaxVariableList from '~/ci_variable_list/ajax_variable_list';
import initVariableList from '~/ci_variable_list';
import DueDateSelectors from '~/due_date_select';

document.addEventListener('DOMContentLoaded', () => {
  // Initialize expandable settings panels
  initSettingsPanels();
  // eslint-disable-next-line no-new
  new DueDateSelectors();

  if (gon.features.newVariablesUi) {
    initVariableList();
  } else {
    const variableListEl = document.querySelector('.js-ci-variable-list-section');
    // eslint-disable-next-line no-new
    new AjaxVariableList({
      container: variableListEl,
      saveButton: variableListEl.querySelector('.js-ci-variables-save-button'),
      errorBox: variableListEl.querySelector('.js-ci-variable-error-box'),
      saveEndpoint: variableListEl.dataset.saveEndpoint,
      maskableRegex: variableListEl.dataset.maskableRegex,
    });
  }
});
