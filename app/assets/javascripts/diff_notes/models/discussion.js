/* eslint-disable guard-for-in, no-restricted-syntax */
/* global NoteModel */

import $ from 'jquery';
import Vue from 'vue';
import { localTimeAgo } from '../../lib/utils/datetime_utility';

class DiscussionModel {
  constructor(discussionId) {
    this.id = discussionId;
    this.notes = {};
    this.loading = false;
    this.canResolve = false;
  }

  createNote(noteObj) {
    Vue.set(this.notes, noteObj.noteId, new NoteModel(this.id, noteObj));
  }

  deleteNote(noteId) {
    Vue.delete(this.notes, noteId);
  }

  getNote(noteId) {
    return this.notes[noteId];
  }

  notesCount() {
    return Object.keys(this.notes).length;
  }

  isResolved() {
    for (const noteId in this.notes) {
      const note = this.notes[noteId];

      if (!note.resolved) {
        return false;
      }
    }
    return true;
  }

  resolveAllNotes(resolvedBy) {
    for (const noteId in this.notes) {
      const note = this.notes[noteId];

      if (!note.resolved) {
        note.resolved = true;
        note.resolved_by = resolvedBy;
      }
    }
  }

  unResolveAllNotes() {
    for (const noteId in this.notes) {
      const note = this.notes[noteId];

      if (note.resolved) {
        note.resolved = false;
        note.resolved_by = null;
      }
    }
  }

  updateHeadline(data) {
    const discussionSelector = `.discussion[data-discussion-id="${this.id}"]`;
    const $discussionHeadline = $(`${discussionSelector} .js-discussion-headline`);

    if (data.discussion_headline_html) {
      if ($discussionHeadline.length) {
        $discussionHeadline.replaceWith(data.discussion_headline_html);
      } else {
        $(`${discussionSelector} .discussion-header`).append(data.discussion_headline_html);
      }

      localTimeAgo($('.js-timeago', `${discussionSelector}`));
    } else {
      $discussionHeadline.remove();
    }
  }

  isResolvable() {
    if (!this.canResolve) {
      return false;
    }

    for (const noteId in this.notes) {
      const note = this.notes[noteId];

      if (note.canResolve) {
        return true;
      }
    }

    return false;
  }
}

window.DiscussionModel = DiscussionModel;
