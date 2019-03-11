import Vue from 'vue';
import $ from 'jquery';
import axios from '~/lib/utils/axios_utils';
import Visibility from 'visibilityjs';
import TaskList from '../../task_list';
import Flash from '../../flash';
import Poll from '../../lib/utils/poll';
import * as types from './mutation_types';
import * as utils from './utils';
import * as constants from '../constants';
import service from '../services/notes_service';
import loadAwardsHandler from '../../awards_handler';
import sidebarTimeTrackingEventHub from '../../sidebar/event_hub';
import { isInViewport, scrollToElement, isInMRPage } from '../../lib/utils/common_utils';
import mrWidgetEventHub from '../../vue_merge_request_widget/event_hub';
import { __ } from '~/locale';

let eTagPoll;

export const expandDiscussion = ({ commit, dispatch }, data) => {
  if (data.discussionId) {
    dispatch('diffs/renderFileForDiscussionId', data.discussionId, { root: true });
  }

  commit(types.EXPAND_DISCUSSION, data);
};

export const collapseDiscussion = ({ commit }, data) => commit(types.COLLAPSE_DISCUSSION, data);

export const setNotesData = ({ commit }, data) => commit(types.SET_NOTES_DATA, data);

export const setNoteableData = ({ commit }, data) => commit(types.SET_NOTEABLE_DATA, data);

export const setUserData = ({ commit }, data) => commit(types.SET_USER_DATA, data);

export const setLastFetchedAt = ({ commit }, data) => commit(types.SET_LAST_FETCHED_AT, data);

export const setInitialNotes = ({ commit }, discussions) =>
  commit(types.SET_INITIAL_DISCUSSIONS, discussions);

export const setTargetNoteHash = ({ commit }, data) => commit(types.SET_TARGET_NOTE_HASH, data);

export const setNotesFetchedState = ({ commit }, state) =>
  commit(types.SET_NOTES_FETCHED_STATE, state);

export const toggleDiscussion = ({ commit }, data) => commit(types.TOGGLE_DISCUSSION, data);

export const fetchDiscussions = ({ commit, dispatch }, { path, filter }) =>
  service
    .fetchDiscussions(path, filter)
    .then(res => res.json())
    .then(discussions => {
      commit(types.SET_INITIAL_DISCUSSIONS, discussions);
      dispatch('updateResolvableDiscussonsCounts');
    });

export const updateDiscussion = ({ commit, state }, discussion) => {
  commit(types.UPDATE_DISCUSSION, discussion);

  return utils.findNoteObjectById(state.discussions, discussion.id);
};

export const deleteNote = ({ commit, dispatch, state }, note) =>
  service.deleteNote(note.path).then(() => {
    const discussion = state.discussions.find(({ id }) => id === note.discussion_id);

    commit(types.DELETE_NOTE, note);

    dispatch('updateMergeRequestWidget');
    dispatch('updateResolvableDiscussonsCounts');

    if (isInMRPage()) {
      dispatch('diffs/removeDiscussionsFromDiff', discussion);
    }
  });

export const updateNote = ({ commit, dispatch }, { endpoint, note }) =>
  service
    .updateNote(endpoint, note)
    .then(res => res.json())
    .then(res => {
      commit(types.UPDATE_NOTE, res);
      dispatch('startTaskList');
    });

export const updateOrCreateNotes = ({ commit, state, getters, dispatch }, notes) => {
  const { notesById } = getters;

  notes.forEach(note => {
    if (notesById[note.id]) {
      commit(types.UPDATE_NOTE, note);
    } else if (note.type === constants.DISCUSSION_NOTE || note.type === constants.DIFF_NOTE) {
      const discussion = utils.findNoteObjectById(state.discussions, note.discussion_id);

      if (discussion) {
        commit(types.ADD_NEW_REPLY_TO_DISCUSSION, note);
      } else if (note.type === constants.DIFF_NOTE) {
        dispatch('fetchDiscussions', { path: state.notesData.discussionsPath });
      } else {
        commit(types.ADD_NEW_NOTE, note);
      }
    } else {
      commit(types.ADD_NEW_NOTE, note);
    }
  });
};

export const replyToDiscussion = ({ commit, state, getters, dispatch }, { endpoint, data }) =>
  service
    .replyToDiscussion(endpoint, data)
    .then(res => res.json())
    .then(res => {
      if (res.discussion) {
        commit(types.UPDATE_DISCUSSION, res.discussion);

        updateOrCreateNotes({ commit, state, getters, dispatch }, res.discussion.notes);

        dispatch('updateMergeRequestWidget');
        dispatch('startTaskList');
        dispatch('updateResolvableDiscussonsCounts');
      } else {
        commit(types.ADD_NEW_REPLY_TO_DISCUSSION, res);
      }

      return res;
    });

export const createNewNote = ({ commit, dispatch }, { endpoint, data }) =>
  service
    .createNewNote(endpoint, data)
    .then(res => res.json())
    .then(res => {
      if (!res.errors) {
        commit(types.ADD_NEW_NOTE, res);

        dispatch('updateMergeRequestWidget');
        dispatch('startTaskList');
        dispatch('updateResolvableDiscussonsCounts');
      }
      return res;
    });

export const removePlaceholderNotes = ({ commit }) => commit(types.REMOVE_PLACEHOLDER_NOTES);

export const toggleResolveNote = ({ commit, dispatch }, { endpoint, isResolved, discussion }) =>
  service
    .toggleResolveNote(endpoint, isResolved)
    .then(res => res.json())
    .then(res => {
      const mutationType = discussion ? types.UPDATE_DISCUSSION : types.UPDATE_NOTE;

      commit(mutationType, res);

      dispatch('updateResolvableDiscussonsCounts');

      dispatch('updateMergeRequestWidget');
    });

export const closeIssue = ({ commit, dispatch, state }) => {
  dispatch('toggleStateButtonLoading', true);
  return service
    .toggleIssueState(state.notesData.closePath)
    .then(res => res.json())
    .then(data => {
      commit(types.CLOSE_ISSUE);
      dispatch('emitStateChangedEvent', data);
      dispatch('toggleStateButtonLoading', false);
    });
};

export const reopenIssue = ({ commit, dispatch, state }) => {
  dispatch('toggleStateButtonLoading', true);
  return service
    .toggleIssueState(state.notesData.reopenPath)
    .then(res => res.json())
    .then(data => {
      commit(types.REOPEN_ISSUE);
      dispatch('emitStateChangedEvent', data);
      dispatch('toggleStateButtonLoading', false);
    });
};

export const toggleStateButtonLoading = ({ commit }, value) =>
  commit(types.TOGGLE_STATE_BUTTON_LOADING, value);

export const emitStateChangedEvent = ({ getters }, data) => {
  const event = new CustomEvent('issuable_vue_app:change', {
    detail: {
      data,
      isClosed: getters.openState === constants.CLOSED,
    },
  });

  document.dispatchEvent(event);
};

export const toggleIssueLocalState = ({ commit }, newState) => {
  if (newState === constants.CLOSED) {
    commit(types.CLOSE_ISSUE);
  } else if (newState === constants.REOPENED) {
    commit(types.REOPEN_ISSUE);
  }
};

export const saveNote = ({ commit, dispatch }, noteData) => {
  // For MR discussuions we need to post as `note[note]` and issue we use `note.note`.
  // For batch comments, we use draft_note
  const note = noteData.data.draft_note || noteData.data['note[note]'] || noteData.data.note.note;
  let placeholderText = note;
  const hasQuickActions = utils.hasQuickActions(placeholderText);
  const replyId = noteData.data.in_reply_to_discussion_id;
  let methodToDispatch;
  const postData = Object.assign({}, noteData);
  if (postData.isDraft === true) {
    methodToDispatch = replyId
      ? 'batchComments/addDraftToDiscussion'
      : 'batchComments/createNewDraft';
    if (!postData.draft_note && noteData.note) {
      postData.draft_note = postData.note;
      delete postData.note;
    }
  } else {
    methodToDispatch = replyId ? 'replyToDiscussion' : 'createNewNote';
  }

  $('.notes-form .flash-container').hide(); // hide previous flash notification
  commit(types.REMOVE_PLACEHOLDER_NOTES); // remove previous placeholders

  if (replyId) {
    if (hasQuickActions) {
      placeholderText = utils.stripQuickActions(placeholderText);
    }

    if (placeholderText.length) {
      commit(types.SHOW_PLACEHOLDER_NOTE, {
        noteBody: placeholderText,
        replyId,
      });
    }

    if (hasQuickActions) {
      commit(types.SHOW_PLACEHOLDER_NOTE, {
        isSystemNote: true,
        noteBody: utils.getQuickActionText(note),
        replyId,
      });
    }
  }

  return dispatch(methodToDispatch, postData, { root: true }).then(res => {
    const { errors } = res;
    const commandsChanges = res.commands_changes;

    if (hasQuickActions && errors && Object.keys(errors).length) {
      eTagPoll.makeRequest();

      $('.js-gfm-input').trigger('clear-commands-cache.atwho');
      Flash('Commands applied', 'notice', noteData.flashContainer);
    }

    if (commandsChanges) {
      if (commandsChanges.emoji_award) {
        const votesBlock = $('.js-awards-block').eq(0);

        loadAwardsHandler()
          .then(awardsHandler => {
            awardsHandler.addAwardToEmojiBar(votesBlock, commandsChanges.emoji_award);
            awardsHandler.scrollToAwards();
          })
          .catch(() => {
            Flash(
              'Something went wrong while adding your award. Please try again.',
              'alert',
              noteData.flashContainer,
            );
          });
      }

      if (commandsChanges.spend_time != null || commandsChanges.time_estimate != null) {
        sidebarTimeTrackingEventHub.$emit('timeTrackingUpdated', res);
      }
    }

    if (errors && errors.commands_only) {
      Flash(errors.commands_only, 'notice', noteData.flashContainer);
    }
    if (replyId) {
      commit(types.REMOVE_PLACEHOLDER_NOTES);
    }

    return res;
  });
};

const pollSuccessCallBack = (resp, commit, state, getters, dispatch) => {
  if (resp.notes && resp.notes.length) {
    updateOrCreateNotes({ commit, state, getters, dispatch }, resp.notes);

    dispatch('startTaskList');
  }

  commit(types.SET_LAST_FETCHED_AT, resp.last_fetched_at);

  return resp;
};

export const poll = ({ commit, state, getters, dispatch }) => {
  eTagPoll = new Poll({
    resource: service,
    method: 'poll',
    data: state,
    successCallback: resp =>
      resp.json().then(data => pollSuccessCallBack(data, commit, state, getters, dispatch)),
    errorCallback: () => Flash('Something went wrong while fetching latest comments.'),
  });

  if (!Visibility.hidden()) {
    eTagPoll.makeRequest();
  } else {
    service.poll(state);
  }

  Visibility.change(() => {
    if (!Visibility.hidden()) {
      eTagPoll.restart();
    } else {
      eTagPoll.stop();
    }
  });
};

export const stopPolling = () => {
  eTagPoll.stop();
};

export const restartPolling = () => {
  eTagPoll.restart();
};

export const fetchData = ({ commit, state, getters }) => {
  const requestData = {
    endpoint: state.notesData.notesPath,
    lastFetchedAt: state.lastFetchedAt,
  };

  service
    .poll(requestData)
    .then(resp => resp.json)
    .then(data => pollSuccessCallBack(data, commit, state, getters))
    .catch(() => Flash('Something went wrong while fetching latest comments.'));
};

export const toggleAward = ({ commit, getters }, { awardName, noteId }) => {
  commit(types.TOGGLE_AWARD, { awardName, note: getters.notesById[noteId] });
};

export const toggleAwardRequest = ({ dispatch }, data) => {
  const { endpoint, awardName } = data;

  return service
    .toggleAward(endpoint, { name: awardName })
    .then(res => res.json())
    .then(() => {
      dispatch('toggleAward', data);
    });
};

export const scrollToNoteIfNeeded = (context, el) => {
  if (!isInViewport(el[0])) {
    scrollToElement(el);
  }
};

export const fetchDiscussionDiffLines = ({ commit }, discussion) =>
  axios.get(discussion.truncated_diff_lines_path).then(({ data }) => {
    commit(types.SET_DISCUSSION_DIFF_LINES, {
      discussionId: discussion.id,
      diffLines: data.truncated_diff_lines,
    });
  });

export const updateMergeRequestWidget = () => {
  mrWidgetEventHub.$emit('mr.discussion.updated');
};

export const setLoadingState = ({ commit }, data) => {
  commit(types.SET_NOTES_LOADING_STATE, data);
};

export const filterDiscussion = ({ dispatch }, { path, filter }) => {
  dispatch('setLoadingState', true);
  dispatch('fetchDiscussions', { path, filter })
    .then(() => {
      dispatch('setLoadingState', false);
      dispatch('setNotesFetchedState', true);
    })
    .catch(() => {
      dispatch('setLoadingState', false);
      dispatch('setNotesFetchedState', true);
      Flash(__('Something went wrong while fetching comments. Please try again.'));
    });
};

export const setCommentsDisabled = ({ commit }, data) => {
  commit(types.DISABLE_COMMENTS, data);
};

export const startTaskList = ({ dispatch }) =>
  Vue.nextTick(
    () =>
      new TaskList({
        dataType: 'note',
        fieldName: 'note',
        selector: '.notes .is-editable',
        onSuccess: () => dispatch('startTaskList'),
      }),
  );

export const updateResolvableDiscussonsCounts = ({ commit }) =>
  commit(types.UPDATE_RESOLVABLE_DISCUSSIONS_COUNTS);

export const submitSuggestion = (
  { commit },
  { discussionId, noteId, suggestionId, flashContainer, callback },
) => {
  service
    .applySuggestion(suggestionId)
    .then(() => {
      commit(types.APPLY_SUGGESTION, { discussionId, noteId, suggestionId });
      callback();
    })
    .catch(err => {
      const defaultMessage = __(
        'Something went wrong while applying the suggestion. Please try again.',
      );
      const flashMessage = err.response.data ? `${err.response.data.message}.` : defaultMessage;

      Flash(__(flashMessage), 'alert', flashContainer);
      callback();
    });
};

export const convertToDiscussion = ({ commit }, noteId) =>
  commit(types.CONVERT_TO_DISCUSSION, noteId);

export const removeConvertedDiscussion = ({ commit }, noteId) =>
  commit(types.REMOVE_CONVERTED_DISCUSSION, noteId);

// prevent babel-plugin-rewire from generating an invalid default during karma tests
export default () => {};
