// NOTE:
// These imports are pulled from 'monaco-editor/esm/vs/editor/editor.main.js'
// We don't want to include 'monaco-editor/esm/vs/editor/edcore' because it causes
// lots of compatability issues with Jest
// Issue: https://gitlab.com/gitlab-org/gitlab/-/issues/209863
import 'monaco-editor/esm/vs/language/typescript/monaco.contribution';
import 'monaco-editor/esm/vs/language/css/monaco.contribution';
import 'monaco-editor/esm/vs/language/json/monaco.contribution';
import 'monaco-editor/esm/vs/language/html/monaco.contribution';
import 'monaco-editor/esm/vs/basic-languages/monaco.contribution';

export * from 'monaco-editor/esm/vs/editor/editor.api';
export default global.monaco;
