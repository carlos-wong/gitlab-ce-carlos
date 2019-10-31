import initMrNotes from '~/mr_notes';
import initSidebarBundle from '~/sidebar/sidebar_bundle';
import initShow from '../init_merge_request_show';

document.addEventListener('DOMContentLoaded', () => {
  initShow();
  if (gon.features && !gon.features.vueIssuableSidebar) {
    initSidebarBundle();
  }
  initMrNotes();
});
