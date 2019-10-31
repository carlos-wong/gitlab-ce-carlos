export const DISCUSSION_NOTE = 'DiscussionNote';
export const DIFF_NOTE = 'DiffNote';
export const DISCUSSION = 'discussion';
export const NOTE = 'note';
export const SYSTEM_NOTE = 'systemNote';
export const COMMENT = 'comment';
export const OPENED = 'opened';
export const REOPENED = 'reopened';
export const CLOSED = 'closed';
export const MERGED = 'merged';
export const ISSUE_NOTEABLE_TYPE = 'issue';
export const EPIC_NOTEABLE_TYPE = 'epic';
export const MERGE_REQUEST_NOTEABLE_TYPE = 'MergeRequest';
export const UNRESOLVE_NOTE_METHOD_NAME = 'delete';
export const RESOLVE_NOTE_METHOD_NAME = 'post';
export const DESCRIPTION_TYPE = 'changed the description';
export const HISTORY_ONLY_FILTER_VALUE = 2;
export const DISCUSSION_FILTERS_DEFAULT_VALUE = 0;
export const DISCUSSION_TAB_LABEL = 'show';
export const NOTE_UNDERSCORE = 'note_';

export const NOTEABLE_TYPE_MAPPING = {
  Issue: ISSUE_NOTEABLE_TYPE,
  MergeRequest: MERGE_REQUEST_NOTEABLE_TYPE,
  Epic: EPIC_NOTEABLE_TYPE,
};

export const DISCUSSION_FILTER_TYPES = {
  ALL: 'all',
  COMMENTS: 'comments',
  HISTORY: 'history',
};
