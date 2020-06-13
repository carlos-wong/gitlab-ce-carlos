import * as types from './mutation_types';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import AccessorUtils from '~/lib/utils/accessor';

export default {
  [types.SET_ERRORS](state, data) {
    state.errors = convertObjectPropsToCamelCase(data, { deep: true });
  },
  [types.SET_LOADING](state, loading) {
    state.loading = loading;
  },
  [types.SET_INDEX_PATH](state, path) {
    state.indexPath = path;
  },
  [types.ADD_RECENT_SEARCH](state, searchTerm) {
    if (searchTerm.length === 0) {
      return;
    }
    // remove any existing item, then add it to the start of the list
    const recentSearches = state.recentSearches.filter(s => s !== searchTerm);
    recentSearches.unshift(searchTerm);
    // only keep the last 5
    state.recentSearches = recentSearches.slice(0, 5);

    if (AccessorUtils.isLocalStorageAccessSafe()) {
      localStorage.setItem(
        `recent-searches${state.indexPath}`,
        JSON.stringify(state.recentSearches),
      );
    }
  },
  [types.CLEAR_RECENT_SEARCHES](state) {
    state.recentSearches = [];
    if (AccessorUtils.isLocalStorageAccessSafe()) {
      localStorage.removeItem(`recent-searches${state.indexPath}`);
    }
  },
  [types.LOAD_RECENT_SEARCHES](state) {
    const recentSearches = localStorage.getItem(`recent-searches${state.indexPath}`) || [];
    try {
      state.recentSearches = JSON.parse(recentSearches);
    } catch (e) {
      state.recentSearches = [];
      throw e;
    }
  },
  [types.SET_PAGINATION](state, pagination) {
    state.pagination = pagination;
  },
  [types.SET_CURSOR](state, cursor) {
    state.cursor = cursor;
  },
  [types.SET_SORT_FIELD](state, field) {
    state.sortField = field;
  },
  [types.SET_SEARCH_QUERY](state, query) {
    state.searchQuery = query;
  },
  [types.SET_ENDPOINT](state, endpoint) {
    state.endpoint = endpoint;
  },
  [types.REMOVE_IGNORED_RESOLVED_ERRORS](state, error) {
    state.errors = state.errors.filter(err => err.id !== error);
  },
  [types.SET_STATUS_FILTER](state, query) {
    state.statusFilter = query;
  },
};
