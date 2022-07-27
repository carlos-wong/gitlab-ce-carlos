import { s__ } from '~/locale';

export const FILTERED_SEARCH_TERM = 'filtered-search-term';
export const FILTERED_SEARCH_TYPE = 'type';
export const HISTORY_PIPELINES_LIMIT = 5;

export const DELETE_PACKAGE_TRACKING_ACTION = 'delete_package';
export const REQUEST_DELETE_PACKAGE_TRACKING_ACTION = 'request_delete_package';
export const CANCEL_DELETE_PACKAGE_TRACKING_ACTION = 'cancel_delete_package';
export const PULL_PACKAGE_TRACKING_ACTION = 'pull_package';
export const DELETE_PACKAGE_FILE_TRACKING_ACTION = 'delete_package_file';
export const REQUEST_DELETE_PACKAGE_FILE_TRACKING_ACTION = 'request_delete_package_file';
export const CANCEL_DELETE_PACKAGE_FILE_TRACKING_ACTION = 'cancel_delete_package_file';
export const DOWNLOAD_PACKAGE_ASSET_TRACKING_ACTION = 'download_package_asset';

export const TRACKING_ACTIONS = {
  DELETE_PACKAGE: DELETE_PACKAGE_TRACKING_ACTION,
  REQUEST_DELETE_PACKAGE: REQUEST_DELETE_PACKAGE_TRACKING_ACTION,
  CANCEL_DELETE_PACKAGE: CANCEL_DELETE_PACKAGE_TRACKING_ACTION,
  PULL_PACKAGE: PULL_PACKAGE_TRACKING_ACTION,
  DELETE_PACKAGE_FILE: DELETE_PACKAGE_FILE_TRACKING_ACTION,
  REQUEST_DELETE_PACKAGE_FILE: REQUEST_DELETE_PACKAGE_FILE_TRACKING_ACTION,
  CANCEL_DELETE_PACKAGE_FILE: CANCEL_DELETE_PACKAGE_FILE_TRACKING_ACTION,
  DOWNLOAD_PACKAGE_ASSET: DOWNLOAD_PACKAGE_ASSET_TRACKING_ACTION,
};

export const SHOW_DELETE_SUCCESS_ALERT = 'showSuccessDeleteAlert';
export const DELETE_PACKAGE_ERROR_MESSAGE = s__(
  'PackageRegistry|Something went wrong while deleting the package.',
);
export const DELETE_PACKAGE_FILE_ERROR_MESSAGE = s__(
  'PackageRegistry|Something went wrong while deleting the package file.',
);
export const DELETE_PACKAGE_FILE_SUCCESS_MESSAGE = s__(
  'PackageRegistry|Package file deleted successfully',
);

export const PACKAGE_ERROR_STATUS = 'error';
export const PACKAGE_DEFAULT_STATUS = 'default';
export const PACKAGE_HIDDEN_STATUS = 'hidden';
export const PACKAGE_PROCESSING_STATUS = 'processing';
