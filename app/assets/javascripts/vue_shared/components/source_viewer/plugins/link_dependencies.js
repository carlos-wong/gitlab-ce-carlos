import packageJsonLinker from './utils/package_json_linker';

const DEPENDENCY_LINKERS = {
  package_json: packageJsonLinker,
};

/**
 * Highlight.js plugin for generating links to dependencies when viewing dependency files.
 *
 * Plugin API: https://github.com/highlightjs/highlight.js/blob/main/docs/plugin-api.rst
 *
 * @param {Object} result - an object that represents the highlighted result from Highlight.js
 * @param {String} fileType - a string containing the file type
 * @param {String} rawContent - raw (non-highlighted) file content
 */
export default (result, fileType, rawContent) => {
  if (DEPENDENCY_LINKERS[fileType]) {
    try {
      // eslint-disable-next-line no-param-reassign
      result.value = DEPENDENCY_LINKERS[fileType](result, rawContent);
    } catch (e) {
      // Shallowed (do nothing), in this case the original unlinked dependencies will be rendered.
    }
  }
};
