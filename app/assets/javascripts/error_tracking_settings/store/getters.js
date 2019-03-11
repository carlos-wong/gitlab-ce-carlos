import _ from 'underscore';
import { __, s__, sprintf } from '~/locale';
import { getDisplayName } from '../utils';

export const hasProjects = state => !!state.projects && state.projects.length > 0;

export const isProjectInvalid = (state, getters) =>
  !!state.selectedProject &&
  getters.hasProjects &&
  !state.projects.some(project => _.isMatch(state.selectedProject, project));

export const dropdownLabel = (state, getters) => {
  if (state.selectedProject !== null) {
    return getDisplayName(state.selectedProject);
  }
  if (!getters.hasProjects) {
    return s__('ErrorTracking|No projects available');
  }
  return s__('ErrorTracking|Select project');
};

export const invalidProjectLabel = state => {
  if (state.selectedProject) {
    return sprintf(
      __('Project "%{name}" is no longer available. Select another project to continue.'),
      {
        name: state.selectedProject.name,
      },
    );
  }
  return '';
};

export const projectSelectionLabel = state => {
  if (state.token) {
    return s__(
      "ErrorTracking|Click 'Connect' to re-establish the connection to Sentry and activate the dropdown.",
    );
  }
  return s__('ErrorTracking|To enable project selection, enter a valid Auth Token');
};

// prevent babel-plugin-rewire from generating an invalid default during karma tests
export default () => {};
