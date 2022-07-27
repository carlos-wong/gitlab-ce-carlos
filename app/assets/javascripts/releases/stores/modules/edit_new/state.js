export default ({
  isExistingRelease,
  projectId,
  groupId,
  groupMilestonesAvailable = false,
  projectPath,
  markdownDocsPath,
  markdownPreviewPath,
  releaseAssetsDocsPath,
  manageMilestonesPath,
  newMilestonePath,
  releasesPagePath,
  editReleaseDocsPath,
  upcomingReleaseDocsPath,

  deleteReleaseDocsPath = '',
  tagName = null,
  defaultBranch = null,
}) => ({
  isExistingRelease,
  projectId,
  groupId,
  groupMilestonesAvailable: Boolean(groupMilestonesAvailable),
  projectPath,
  markdownDocsPath,
  markdownPreviewPath,
  releaseAssetsDocsPath,
  manageMilestonesPath,
  newMilestonePath,
  releasesPagePath,
  editReleaseDocsPath,
  upcomingReleaseDocsPath,
  deleteReleaseDocsPath,

  /**
   * The name of the tag associated with the release, provided by the backend.
   * When creating a new release, this is the default from the URL
   */
  tagName,
  showCreateFrom: !tagName,

  defaultBranch,
  createFrom: defaultBranch,

  /** The Release object */
  release: null,

  /**
   * A deep clone of the Release object above.
   * Used when editing this Release so that
   * changes can be computed.
   */
  originalRelease: null,

  isFetchingRelease: false,
  fetchError: null,

  isUpdatingRelease: false,
  updateError: null,

  tagNotes: '',
  includeTagNotes: false,
  existingRelease: null,
});
