import axios from '~/lib/utils/axios_utils';
import createFlash from '~/flash';
import * as types from './mutation_types';
import { errorMessages, errorMessagesTypes } from '../constants';

export const fetchRepos = ({ commit, state }) => {
  commit(types.TOGGLE_MAIN_LOADING);

  return axios
    .get(state.endpoint)
    .then(({ data }) => {
      commit(types.TOGGLE_MAIN_LOADING);
      commit(types.SET_REPOS_LIST, data);
    })
    .catch(() => {
      commit(types.TOGGLE_MAIN_LOADING);
      createFlash(errorMessages[errorMessagesTypes.FETCH_REPOS]);
    });
};

export const fetchList = ({ commit }, { repo, page }) => {
  commit(types.TOGGLE_REGISTRY_LIST_LOADING, repo);

  return axios
    .get(repo.tagsPath, { params: { page } })
    .then(response => {
      const { headers, data } = response;

      commit(types.TOGGLE_REGISTRY_LIST_LOADING, repo);
      commit(types.SET_REGISTRY_LIST, { repo, resp: data, headers });
    })
    .catch(() => {
      commit(types.TOGGLE_REGISTRY_LIST_LOADING, repo);
      createFlash(errorMessages[errorMessagesTypes.FETCH_REGISTRY]);
    });
};

export const deleteItem = (_, item) => axios.delete(item.destroyPath);
export const multiDeleteItems = (_, { path, items }) =>
  axios.delete(path, { params: { ids: items } });

export const setMainEndpoint = ({ commit }, data) => commit(types.SET_MAIN_ENDPOINT, data);
export const toggleLoading = ({ commit }) => commit(types.TOGGLE_MAIN_LOADING);

// prevent babel-plugin-rewire from generating an invalid default during karma tests
export default () => {};
