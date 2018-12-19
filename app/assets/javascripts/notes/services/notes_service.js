import Vue from 'vue';
import Api from '~/api';
import VueResource from 'vue-resource';
import * as constants from '../constants';

Vue.use(VueResource);

export default {
  fetchDiscussions(endpoint, filter) {
    const config = filter !== undefined ? { params: { notes_filter: filter } } : null;
    return Vue.http.get(endpoint, config);
  },
  deleteNote(endpoint) {
    return Vue.http.delete(endpoint);
  },
  replyToDiscussion(endpoint, data) {
    return Vue.http.post(endpoint, data, { emulateJSON: true });
  },
  updateNote(endpoint, data) {
    return Vue.http.put(endpoint, data, { emulateJSON: true });
  },
  createNewNote(endpoint, data) {
    return Vue.http.post(endpoint, data, { emulateJSON: true });
  },
  toggleResolveNote(endpoint, isResolved) {
    const { RESOLVE_NOTE_METHOD_NAME, UNRESOLVE_NOTE_METHOD_NAME } = constants;
    const method = isResolved ? UNRESOLVE_NOTE_METHOD_NAME : RESOLVE_NOTE_METHOD_NAME;

    return Vue.http[method](endpoint);
  },
  poll(data = {}) {
    const endpoint = data.notesData.notesPath;
    const { lastFetchedAt } = data;
    const options = {
      headers: {
        'X-Last-Fetched-At': lastFetchedAt ? `${lastFetchedAt}` : undefined,
      },
    };

    return Vue.http.get(endpoint, options);
  },
  toggleAward(endpoint, data) {
    return Vue.http.post(endpoint, data, { emulateJSON: true });
  },
  toggleIssueState(endpoint, data) {
    return Vue.http.put(endpoint, data);
  },
  applySuggestion(id) {
    return Api.applySuggestion(id);
  },
};
