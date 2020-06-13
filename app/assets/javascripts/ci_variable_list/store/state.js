import { displayText } from '../constants';

export default () => ({
  endpoint: null,
  projectId: null,
  isGroup: null,
  maskableRegex: null,
  isLoading: false,
  isDeleting: false,
  variable: {
    variable_type: displayText.variableText,
    key: '',
    secret_value: '',
    protected: false,
    masked: false,
    environment_scope: displayText.allEnvironmentsText,
  },
  variables: null,
  valuesHidden: true,
  error: null,
  environments: [],
  typeOptions: [displayText.variableText, displayText.fileText],
  variableBeingEdited: null,
});
