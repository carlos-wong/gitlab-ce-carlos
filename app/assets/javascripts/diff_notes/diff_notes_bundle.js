/* eslint-disable func-names, new-cap */

import $ from 'jquery';
import Vue from 'vue';
import './models/discussion';
import './models/note';
import './stores/comments';
import './services/resolve';
import './mixins/discussion';
import './components/comment_resolve_btn';
import './components/jump_to_discussion';
import './components/resolve_btn';
import './components/resolve_count';
import './components/diff_note_avatars';
import './components/new_issue_for_discussion';

export default () => {
  const projectPathHolder =
    document.querySelector('.merge-request') || document.querySelector('.commit-box');
  const { projectPath } = projectPathHolder.dataset;
  const COMPONENT_SELECTOR =
    'resolve-btn, jump-to-discussion, comment-and-resolve-btn, new-issue-for-discussion-btn';

  window.gl = window.gl || {};
  window.gl.diffNoteApps = {};

  window.ResolveService = new gl.DiffNotesResolveServiceClass(projectPath);

  gl.diffNotesCompileComponents = () => {
    $('diff-note-avatars').each(function() {
      const tmp = Vue.extend({
        template: $(this).get(0).outerHTML,
      });
      const tmpApp = new tmp().$mount();

      $(this).replaceWith(tmpApp.$el);
      $(tmpApp.$el).one('remove.vue', () => {
        tmpApp.$destroy();
        tmpApp.$el.remove();
      });
    });

    const $components = $(COMPONENT_SELECTOR).filter(function() {
      return $(this).closest('resolve-count').length !== 1;
    });

    if ($components) {
      $components.each(function() {
        const $this = $(this);
        const noteId = $this.attr(':note-id');
        const discussionId = $this.attr(':discussion-id');

        if ($this.is('comment-and-resolve-btn') && !discussionId) return;

        const tmp = Vue.extend({
          template: $this.get(0).outerHTML,
        });
        const tmpApp = new tmp().$mount();

        if (noteId) {
          gl.diffNoteApps[`note_${noteId}`] = tmpApp;
        }

        $this.replaceWith(tmpApp.$el);
      });
    }
  };

  gl.diffNotesCompileComponents();

  $(window).trigger('resize.nav');
};
