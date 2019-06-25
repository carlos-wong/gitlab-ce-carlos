export const defaultEditorOptions = {
  model: null,
  readOnly: false,
  contextmenu: true,
  scrollBeyondLastLine: false,
  minimap: {
    enabled: false,
  },
  wordWrap: 'on',
};

export default [
  {
    readOnly: model => Boolean(model.file.file_lock),
    quickSuggestions: model => !(model.language === 'markdown'),
  },
];
