import { s__, __ } from '~/locale';

export const integrationLevels = {
  PROJECT: 'project',
  GROUP: 'group',
  INSTANCE: 'instance',
};

export const defaultIntegrationLevel = integrationLevels.INSTANCE;

export const overrideDropdownDescriptions = {
  [integrationLevels.GROUP]: s__(
    'Integrations|Default settings are inherited from the group level.',
  ),
  [integrationLevels.INSTANCE]: s__(
    'Integrations|Default settings are inherited from the instance level.',
  ),
};

export const I18N_FETCH_TEST_SETTINGS_DEFAULT_ERROR_MESSAGE = s__(
  'Integrations|Connection failed. Check your integration settings.',
);
export const I18N_DEFAULT_ERROR_MESSAGE = __('Something went wrong on our end.');
export const I18N_SUCCESSFUL_CONNECTION_MESSAGE = s__('Integrations|Connection successful.');

export const settingsTabTitle = __('Settings');
export const overridesTabTitle = s__('Integrations|Projects using custom settings');

export const integrationFormSections = {
  CONFIGURATION: 'configuration',
  CONNECTION: 'connection',
  JIRA_TRIGGER: 'jira_trigger',
  JIRA_ISSUES: 'jira_issues',
  TRIGGER: 'trigger',
};

export const integrationFormSectionComponents = {
  [integrationFormSections.CONFIGURATION]: 'IntegrationSectionConfiguration',
  [integrationFormSections.CONNECTION]: 'IntegrationSectionConnection',
  [integrationFormSections.JIRA_TRIGGER]: 'IntegrationSectionJiraTrigger',
  [integrationFormSections.JIRA_ISSUES]: 'IntegrationSectionJiraIssues',
  [integrationFormSections.TRIGGER]: 'IntegrationSectionTrigger',
};

export const integrationTriggerEvents = {
  PUSH: 'push_events',
  ISSUE: 'issues_events',
  CONFIDENTIAL_ISSUE: 'confidential_issues_events',
  MERGE_REQUEST: 'merge_requests_events',
  NOTE: 'note_events',
  CONFIDENTIAL_NOTE: 'confidential_note_events',
  TAG_PUSH: 'tag_push_events',
  PIPELINE: 'pipeline_events',
  WIKI_PAGE: 'wiki_page_events',
};

export const integrationTriggerEventTitles = {
  [integrationTriggerEvents.PUSH]: s__('IntegrationEvents|A push is made to the repository'),
  [integrationTriggerEvents.ISSUE]: s__(
    'IntegrationEvents|An issue is created, updated, or closed',
  ),
  [integrationTriggerEvents.CONFIDENTIAL_ISSUE]: s__(
    'IntegrationEvents|A confidential issue is created, updated, or closed',
  ),
  [integrationTriggerEvents.MERGE_REQUEST]: s__(
    'IntegrationEvents|A merge request is created, updated, or merged',
  ),
  [integrationTriggerEvents.NOTE]: s__('IntegrationEvents|A comment is added on an issue'),
  [integrationTriggerEvents.CONFIDENTIAL_NOTE]: s__(
    'IntegrationEvents|A comment is added on a confidential issue',
  ),
  [integrationTriggerEvents.TAG_PUSH]: s__('IntegrationEvents|A tag is pushed to the repository'),
  [integrationTriggerEvents.PIPELINE]: s__('IntegrationEvents|A pipeline status changes'),
  [integrationTriggerEvents.WIKI_PAGE]: s__('IntegrationEvents|A wiki page is created or updated'),
};

export const billingPlans = {
  PREMIUM: 'premium',
  ULTIMATE: 'ultimate',
};

export const billingPlanNames = {
  [billingPlans.PREMIUM]: s__('BillingPlans|Premium'),
  [billingPlans.ULTIMATE]: s__('BillingPlans|Ultimate'),
};

const INTEGRATION_TYPE_SLACK = 'slack';
const INTEGRATION_TYPE_MATTERMOST = 'mattermost';

export const placeholderForType = {
  [INTEGRATION_TYPE_SLACK]: __('#general, #development'),
  [INTEGRATION_TYPE_MATTERMOST]: __('my-channel'),
};
