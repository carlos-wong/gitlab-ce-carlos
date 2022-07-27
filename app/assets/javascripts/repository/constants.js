import { __ } from '~/locale';

export const TREE_PAGE_LIMIT = 1000; // the maximum amount of items per page
export const TREE_PAGE_SIZE = 100; // the amount of items to be fetched per (batch) request
export const TREE_INITIAL_FETCH_COUNT = TREE_PAGE_LIMIT / TREE_PAGE_SIZE; // the amount of (batch) requests to make

export const COMMIT_BATCH_SIZE = 25; // we request commit data in batches of 25

export const SECONDARY_OPTIONS_TEXT = __('Cancel');
export const COMMIT_LABEL = __('Commit message');
export const TARGET_BRANCH_LABEL = __('Target branch');
export const TOGGLE_CREATE_MR_LABEL = __('Start a new merge request with these changes');
export const NEW_BRANCH_IN_FORK = __(
  'GitLab will create a branch in your fork and start a merge request.',
);

export const COMMIT_MESSAGE_SUBJECT_MAX_LENGTH = 52;
export const COMMIT_MESSAGE_BODY_MAX_LENGTH = 72;

export const LIMITED_CONTAINER_WIDTH_CLASS = 'limit-container-width';

export const I18N_COMMIT_DATA_FETCH_ERROR = __('An error occurred while fetching commit data.');

export const PDF_MAX_FILE_SIZE = 10000000; // 10 MB
export const PDF_MAX_PAGE_LIMIT = 50;

export const ROW_APPEAR_DELAY = 150;

export const DEFAULT_BLOB_INFO = {
  gitpodEnabled: false,
  currentUser: {
    gitpodEnabled: false,
    preferencesGitpodPath: null,
    profileEnableGitpodPath: null,
  },
  userPermissions: {
    pushCode: false,
    downloadCode: false,
    createMergeRequestIn: false,
    forkProject: false,
  },
  pathLocks: {
    nodes: [],
  },
  repository: {
    empty: true,
    blobs: {
      nodes: [
        {
          name: '',
          size: '',
          rawTextBlob: '',
          type: '',
          fileType: '',
          tooLarge: false,
          path: '',
          editBlobPath: '',
          gitpodBlobUrl: '',
          ideEditPath: '',
          forkAndEditPath: '',
          ideForkAndEditPath: '',
          codeNavigationPath: '',
          projectBlobPathRoot: '',
          forkAndViewPath: '',
          storedExternally: false,
          externalStorage: '',
          environmentFormattedExternalUrl: '',
          environmentExternalUrlForRouteMap: '',
          canModifyBlob: false,
          canCurrentUserPushToBranch: false,
          archived: false,
          rawPath: '',
          externalStorageUrl: '',
          replacePath: '',
          pipelineEditorPath: '',
          deletePath: '',
          simpleViewer: {},
          richViewer: null,
          webPath: '',
        },
      ],
    },
  },
};

export const TEXT_FILE_TYPE = 'text';

export const LFS_STORAGE = 'lfs';

/**
 * We have some features (like linking to external dependencies) that our frontend highlighter
 * do not yet support.
 * These are file types that we want the legacy (backend) syntax highlighter to highlight.
 */
export const LEGACY_FILE_TYPES = [
  'gemfile',
  'gemspec',
  'composer_json',
  'podfile',
  'podspec',
  'podspec_json',
  'cartfile',
  'godeps_json',
  'requirements_txt',
  'cargo_toml',
  'go_mod',
  'go_sum',
];
