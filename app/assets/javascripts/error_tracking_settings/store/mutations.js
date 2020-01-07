import _ from 'underscore';
import { convertObjectPropsToCamelCase, parseBoolean } from '~/lib/utils/common_utils';
import * as types from './mutation_types';
import { projectKeys } from '../utils';

export default {
  [types.CLEAR_PROJECTS](state) {
    state.projects = [];
  },
  [types.RECEIVE_PROJECTS](state, projects) {
    state.projects = projects
      .map(convertObjectPropsToCamelCase)
      // The `pick` strips out extra properties returned from Sentry.
      // Such properties could be problematic later, e.g. when checking whether `projects` contains `selectedProject`
      .map(project => _.pick(project, projectKeys));
  },
  [types.RESET_CONNECT](state) {
    state.connectSuccessful = false;
    state.connectError = false;
  },
  [types.SET_INITIAL_STATE](
    state,
    { apiHost, enabled, project, token, listProjectsEndpoint, operationsSettingsEndpoint },
  ) {
    state.enabled = parseBoolean(enabled);
    state.apiHost = apiHost;
    state.token = token;
    state.listProjectsEndpoint = listProjectsEndpoint;
    state.operationsSettingsEndpoint = operationsSettingsEndpoint;

    if (project) {
      state.selectedProject = _.pick(
        convertObjectPropsToCamelCase(JSON.parse(project)),
        projectKeys,
      );
    }
  },
  [types.UPDATE_API_HOST](state, apiHost) {
    state.apiHost = apiHost;
  },
  [types.UPDATE_ENABLED](state, enabled) {
    state.enabled = enabled;
  },
  [types.UPDATE_TOKEN](state, token) {
    state.token = token;
  },
  [types.UPDATE_SELECTED_PROJECT](state, selectedProject) {
    state.selectedProject = selectedProject;
  },
  [types.UPDATE_SETTINGS_LOADING](state, settingsLoading) {
    state.settingsLoading = settingsLoading;
  },
  [types.UPDATE_CONNECT_SUCCESS](state) {
    state.connectSuccessful = true;
    state.connectError = false;
  },
  [types.UPDATE_CONNECT_ERROR](state) {
    state.connectSuccessful = false;
    state.connectError = true;
  },
  [types.SET_PROJECTS_LOADING](state, loading) {
    state.isLoadingProjects = loading;
  },
};
