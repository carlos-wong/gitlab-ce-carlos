import IssuableBulkUpdateSidebar from './issuable_bulk_update_sidebar';
import issuableBulkUpdateActions from './issuable_bulk_update_actions';

export default {
  bulkUpdateSidebar: null,

  init(prefixId) {
    const bulkUpdateEl = document.querySelector('.issues-bulk-update');
    const alreadyInitialized = Boolean(this.bulkUpdateSidebar);

    if (bulkUpdateEl && !alreadyInitialized) {
      issuableBulkUpdateActions.init({ prefixId });

      this.bulkUpdateSidebar = new IssuableBulkUpdateSidebar();
    }

    return this.bulkUpdateSidebar;
  },
};
