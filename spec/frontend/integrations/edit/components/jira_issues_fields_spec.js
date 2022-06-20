import { GlFormCheckbox, GlFormInput } from '@gitlab/ui';
import { nextTick } from 'vue';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';

import JiraIssuesFields from '~/integrations/edit/components/jira_issues_fields.vue';
import { createStore } from '~/integrations/edit/store';

describe('JiraIssuesFields', () => {
  let store;
  let wrapper;

  const defaultProps = {
    showJiraIssuesIntegration: true,
    showJiraVulnerabilitiesIntegration: true,
    upgradePlanPath: 'https://gitlab.com',
  };

  const createComponent = ({
    isInheriting = false,
    mountFn = mountExtended,
    props,
    ...options
  } = {}) => {
    store = createStore({
      defaultState: isInheriting ? {} : undefined,
    });

    wrapper = mountFn(JiraIssuesFields, {
      propsData: { ...defaultProps, ...props },
      store,
      stubs: ['jira-issue-creation-vulnerabilities'],
      ...options,
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  const findEnableCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findEnableCheckboxDisabled = () =>
    findEnableCheckbox().find('[type=checkbox]').attributes('disabled');
  const findProjectKey = () => wrapper.findComponent(GlFormInput);
  const findProjectKeyFormGroup = () => wrapper.findByTestId('project-key-form-group');
  const findPremiumUpgradeCTA = () => wrapper.findByTestId('premium-upgrade-cta');
  const findUltimateUpgradeCTA = () => wrapper.findByTestId('ultimate-upgrade-cta');
  const findJiraForVulnerabilities = () => wrapper.findByTestId('jira-for-vulnerabilities');
  const setEnableCheckbox = async (isEnabled = true) =>
    findEnableCheckbox().vm.$emit('input', isEnabled);

  const assertProjectKeyState = (expectedStateValue) => {
    expect(findProjectKey().attributes('state')).toBe(expectedStateValue);
    expect(findProjectKeyFormGroup().attributes('state')).toBe(expectedStateValue);
  };

  describe('template', () => {
    describe.each`
      showJiraIssuesIntegration | showJiraVulnerabilitiesIntegration
      ${false}                  | ${false}
      ${false}                  | ${true}
      ${true}                   | ${false}
      ${true}                   | ${true}
    `(
      'when `showJiraIssuesIntegration` is $jiraIssues and `showJiraVulnerabilitiesIntegration` is $jiraVulnerabilities',
      ({ showJiraIssuesIntegration, showJiraVulnerabilitiesIntegration }) => {
        beforeEach(() => {
          createComponent({
            props: {
              showJiraIssuesIntegration,
              showJiraVulnerabilitiesIntegration,
            },
          });
        });

        if (showJiraIssuesIntegration) {
          it('renders enable checkbox', () => {
            expect(findEnableCheckbox().exists()).toBe(true);
            expect(findEnableCheckboxDisabled()).toBeUndefined();
          });

          it('does not render the Premium CTA', () => {
            expect(findPremiumUpgradeCTA().exists()).toBe(false);
          });

          if (!showJiraVulnerabilitiesIntegration) {
            it.each`
              scenario                                                                          | enableJiraIssues
              ${'when "Enable Jira issues" is checked, renders Ultimate upgrade CTA'}           | ${true}
              ${'when "Enable Jira issues" is unchecked, does not render Ultimate upgrade CTA'} | ${false}
            `('$scenario', async ({ enableJiraIssues }) => {
              if (enableJiraIssues) {
                await setEnableCheckbox();
              }
              expect(findUltimateUpgradeCTA().exists()).toBe(enableJiraIssues);
            });
          }
        } else {
          it('does not render enable checkbox', () => {
            expect(findEnableCheckbox().exists()).toBe(false);
          });

          it('renders the Premium CTA', () => {
            const premiumUpgradeCTA = findPremiumUpgradeCTA();

            expect(premiumUpgradeCTA.exists()).toBe(true);
            expect(premiumUpgradeCTA.props('upgradePlanPath')).toBe(defaultProps.upgradePlanPath);
          });
        }

        it('does not render the Ultimate CTA', () => {
          expect(findUltimateUpgradeCTA().exists()).toBe(false);
        });
      },
    );

    describe('Enable Jira issues checkbox', () => {
      beforeEach(() => {
        createComponent({ props: { initialProjectKey: '' } });
      });

      it('does not render project_key input', () => {
        expect(findProjectKey().exists()).toBe(false);
      });

      // As per https://vuejs.org/v2/guide/forms.html#Checkbox-1,
      // browsers don't include unchecked boxes in form submissions.
      it('includes issues_enabled as false even if unchecked', () => {
        expect(wrapper.find('input[name="service[issues_enabled]"]').exists()).toBe(true);
      });

      describe('when isInheriting = true', () => {
        it('disables checkbox', () => {
          createComponent({ isInheriting: true });

          expect(findEnableCheckboxDisabled()).toBe('disabled');
        });
      });

      describe('on enable issues', () => {
        it('renders project_key input as required', async () => {
          await setEnableCheckbox(true);

          expect(findProjectKey().exists()).toBe(true);
          expect(findProjectKey().attributes('required')).toBe('required');
        });
      });
    });

    describe('Vulnerabilities creation', () => {
      beforeEach(() => {
        createComponent();
      });

      it.each([true, false])(
        'shows the jira-vulnerabilities component correctly when jira issues enables is set to "%s"',
        async (hasJiraIssuesEnabled) => {
          await setEnableCheckbox(hasJiraIssuesEnabled);

          expect(findJiraForVulnerabilities().exists()).toBe(hasJiraIssuesEnabled);
        },
      );

      it('passes down the correct show-full-feature property', async () => {
        await setEnableCheckbox(true);
        expect(findJiraForVulnerabilities().attributes('show-full-feature')).toBe('true');
        wrapper.setProps({ showJiraVulnerabilitiesIntegration: false });
        await nextTick();
        expect(findJiraForVulnerabilities().attributes('show-full-feature')).toBeUndefined();
      });

      it('passes down the correct initial-issue-type-id value when value is empty', async () => {
        await setEnableCheckbox(true);
        expect(findJiraForVulnerabilities().attributes('initial-issue-type-id')).toBeUndefined();
      });

      it('passes down the correct initial-issue-type-id value when value is not empty', async () => {
        const jiraIssueType = 'some-jira-issue-type';
        wrapper.setProps({ initialVulnerabilitiesIssuetype: jiraIssueType });
        await setEnableCheckbox(true);
        expect(findJiraForVulnerabilities().attributes('initial-issue-type-id')).toBe(
          jiraIssueType,
        );
      });

      it('emits "request-jira-issue-types` when the jira-vulnerabilities component requests to fetch issue types', async () => {
        await setEnableCheckbox(true);
        await findJiraForVulnerabilities().vm.$emit('request-jira-issue-types');

        expect(wrapper.emitted('request-jira-issue-types')).toHaveLength(1);
      });
    });

    describe('Project key input field', () => {
      it('sets Project Key `state` attribute to `true` by default', () => {
        createComponent({
          props: {
            initialProjectKey: '',
            initialEnableJiraIssues: true,
          },
          mountFn: shallowMountExtended,
        });

        assertProjectKeyState('true');
      });

      describe('when `isValidated` prop is true', () => {
        beforeEach(() => {
          createComponent({
            props: {
              initialProjectKey: '',
              initialEnableJiraIssues: true,
              isValidated: true,
            },
            mountFn: shallowMountExtended,
          });
        });

        describe('with no project key', () => {
          it('sets Project Key `state` attribute to `undefined`', async () => {
            assertProjectKeyState(undefined);
          });
        });

        describe('when project key is set', () => {
          it('sets Project Key `state` attribute to `true`', async () => {
            // set the project key
            await findProjectKey().vm.$emit('input', 'AB');

            assertProjectKeyState('true');
          });
        });
      });
    });
  });
});
