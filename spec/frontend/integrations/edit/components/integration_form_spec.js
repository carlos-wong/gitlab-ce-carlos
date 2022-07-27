import { GlBadge, GlForm } from '@gitlab/ui';
import axios from 'axios';
import MockAdapter from 'axios-mock-adapter';
import * as Sentry from '@sentry/browser';
import { setHTMLFixture } from 'helpers/fixtures';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import ActiveCheckbox from '~/integrations/edit/components/active_checkbox.vue';
import ConfirmationModal from '~/integrations/edit/components/confirmation_modal.vue';
import DynamicField from '~/integrations/edit/components/dynamic_field.vue';
import IntegrationForm from '~/integrations/edit/components/integration_form.vue';
import OverrideDropdown from '~/integrations/edit/components/override_dropdown.vue';
import ResetConfirmationModal from '~/integrations/edit/components/reset_confirmation_modal.vue';
import TriggerFields from '~/integrations/edit/components/trigger_fields.vue';
import IntegrationSectionConnection from '~/integrations/edit/components/sections/connection.vue';

import {
  integrationLevels,
  I18N_SUCCESSFUL_CONNECTION_MESSAGE,
  I18N_DEFAULT_ERROR_MESSAGE,
  billingPlans,
  billingPlanNames,
} from '~/integrations/constants';
import { createStore } from '~/integrations/edit/store';
import httpStatus from '~/lib/utils/http_status';
import { refreshCurrentPage } from '~/lib/utils/url_utility';
import {
  mockIntegrationProps,
  mockField,
  mockSectionConnection,
  mockSectionJiraIssues,
} from '../mock_data';

jest.mock('@sentry/browser');
jest.mock('~/lib/utils/url_utility');

describe('IntegrationForm', () => {
  const mockToastShow = jest.fn();

  let wrapper;
  let dispatch;
  let mockAxios;

  const createComponent = ({
    customStateProps = {},
    initialState = {},
    provide = {},
    mountFn = shallowMountExtended,
  } = {}) => {
    const store = createStore({
      customState: { ...mockIntegrationProps, ...customStateProps },
      ...initialState,
    });
    dispatch = jest.spyOn(store, 'dispatch').mockImplementation();

    wrapper = mountFn(IntegrationForm, {
      provide,
      store,
      stubs: {
        OverrideDropdown,
        ActiveCheckbox,
        ConfirmationModal,
        TriggerFields,
      },
      mocks: {
        $toast: {
          show: mockToastShow,
        },
      },
    });
  };

  const findOverrideDropdown = () => wrapper.findComponent(OverrideDropdown);
  const findActiveCheckbox = () => wrapper.findComponent(ActiveCheckbox);
  const findConfirmationModal = () => wrapper.findComponent(ConfirmationModal);
  const findResetConfirmationModal = () => wrapper.findComponent(ResetConfirmationModal);
  const findResetButton = () => wrapper.findByTestId('reset-button');
  const findProjectSaveButton = () => wrapper.findByTestId('save-button');
  const findInstanceOrGroupSaveButton = () => wrapper.findByTestId('save-button-instance-group');
  const findTestButton = () => wrapper.findByTestId('test-button');
  const findTriggerFields = () => wrapper.findComponent(TriggerFields);
  const findGlBadge = () => wrapper.findComponent(GlBadge);
  const findGlForm = () => wrapper.findComponent(GlForm);
  const findRedirectToField = () => wrapper.findByTestId('redirect-to-field');
  const findDynamicField = () => wrapper.findComponent(DynamicField);
  const findAllDynamicFields = () => wrapper.findAllComponents(DynamicField);
  const findAllSections = () => wrapper.findAllByTestId('integration-section');
  const findConnectionSection = () => findAllSections().at(0);
  const findConnectionSectionComponent = () =>
    findConnectionSection().findComponent(IntegrationSectionConnection);

  beforeEach(() => {
    mockAxios = new MockAdapter(axios);
  });

  afterEach(() => {
    wrapper.destroy();
    mockAxios.restore();
  });

  describe('template', () => {
    describe('integrationLevel is instance', () => {
      it('renders ConfirmationModal', () => {
        createComponent({
          customStateProps: {
            integrationLevel: integrationLevels.INSTANCE,
          },
        });

        expect(findConfirmationModal().exists()).toBe(true);
      });

      describe('resetPath is empty', () => {
        it('does not render ResetConfirmationModal and button', () => {
          createComponent({
            customStateProps: {
              integrationLevel: integrationLevels.INSTANCE,
            },
          });

          expect(findResetButton().exists()).toBe(false);
          expect(findResetConfirmationModal().exists()).toBe(false);
        });
      });

      describe('resetPath is present', () => {
        it('renders ResetConfirmationModal and button', () => {
          createComponent({
            customStateProps: {
              integrationLevel: integrationLevels.INSTANCE,
              resetPath: 'resetPath',
            },
          });

          expect(findResetButton().exists()).toBe(true);
          expect(findResetConfirmationModal().exists()).toBe(true);
        });
      });
    });

    describe('integrationLevel is group', () => {
      it('renders ConfirmationModal', () => {
        createComponent({
          customStateProps: {
            integrationLevel: integrationLevels.GROUP,
          },
        });

        expect(findConfirmationModal().exists()).toBe(true);
      });

      describe('resetPath is empty', () => {
        it('does not render ResetConfirmationModal and button', () => {
          createComponent({
            customStateProps: {
              integrationLevel: integrationLevels.GROUP,
            },
          });

          expect(findResetButton().exists()).toBe(false);
          expect(findResetConfirmationModal().exists()).toBe(false);
        });
      });

      describe('resetPath is present', () => {
        it('renders ResetConfirmationModal and button', () => {
          createComponent({
            customStateProps: {
              integrationLevel: integrationLevels.GROUP,
              resetPath: 'resetPath',
            },
          });

          expect(findResetButton().exists()).toBe(true);
          expect(findResetConfirmationModal().exists()).toBe(true);
        });
      });
    });

    describe('integrationLevel is project', () => {
      it('does not render ConfirmationModal', () => {
        createComponent({
          customStateProps: {
            integrationLevel: 'project',
          },
        });

        expect(findConfirmationModal().exists()).toBe(false);
      });

      it('does not render ResetConfirmationModal and button', () => {
        createComponent({
          customStateProps: {
            integrationLevel: 'project',
            resetPath: 'resetPath',
          },
        });

        expect(findResetButton().exists()).toBe(false);
        expect(findResetConfirmationModal().exists()).toBe(false);
      });
    });

    describe('triggerEvents is present', () => {
      it('renders TriggerFields', () => {
        const events = [{ title: 'push' }];
        const type = 'slack';

        createComponent({
          customStateProps: {
            triggerEvents: events,
            type,
          },
        });

        expect(findTriggerFields().exists()).toBe(true);
        expect(findTriggerFields().props('events')).toBe(events);
        expect(findTriggerFields().props('type')).toBe(type);
      });
    });

    describe('fields is present', () => {
      it('renders DynamicField for each field without a section', () => {
        const sectionFields = [
          { name: 'username', type: 'text', section: mockSectionConnection.type },
          { name: 'API token', type: 'password', section: mockSectionConnection.type },
        ];

        const nonSectionFields = [
          { name: 'branch', type: 'text' },
          { name: 'labels', type: 'select' },
        ];

        createComponent({
          customStateProps: {
            sections: [mockSectionConnection],
            fields: [...sectionFields, ...nonSectionFields],
          },
        });

        const dynamicFields = findAllDynamicFields();

        expect(dynamicFields).toHaveLength(2);
        dynamicFields.wrappers.forEach((field, index) => {
          expect(field.props()).toMatchObject(nonSectionFields[index]);
        });
      });
    });

    describe('defaultState state is null', () => {
      it('does not render OverrideDropdown', () => {
        createComponent({
          initialState: {
            defaultState: null,
          },
        });

        expect(findOverrideDropdown().exists()).toBe(false);
      });
    });

    describe('defaultState state is an object', () => {
      it('renders OverrideDropdown', () => {
        createComponent({
          initialState: {
            defaultState: {
              ...mockIntegrationProps,
            },
          },
        });

        expect(findOverrideDropdown().exists()).toBe(true);
      });
    });

    describe('with `helpHtml` provided', () => {
      const mockTestId = 'jest-help-html-test';

      setHTMLFixture(`
        <div data-testid="${mockTestId}">
          <svg class="gl-icon">
            <use></use>
          </svg>
          <a data-confirm="Are you sure?" data-method="delete" href="/settings/slack"></a>
        </div>
      `);

      it('renders `helpHtml`', () => {
        const mockHelpHtml = document.querySelector(`[data-testid="${mockTestId}"]`);

        createComponent({
          provide: {
            helpHtml: mockHelpHtml.outerHTML,
          },
        });

        const helpHtml = wrapper.findByTestId(mockTestId);
        const helpLink = helpHtml.find('a');

        expect(helpHtml.isVisible()).toBe(true);
        expect(helpHtml.find('svg').isVisible()).toBe(true);
        expect(helpLink.attributes()).toMatchObject({
          'data-confirm': 'Are you sure?',
          'data-method': 'delete',
        });
      });
    });

    it('renders hidden fields', () => {
      createComponent({
        customStateProps: {
          redirectTo: '/services',
        },
      });

      expect(findRedirectToField().attributes('value')).toBe('/services');
    });
  });

  describe('when integration has sections', () => {
    beforeEach(() => {
      createComponent({
        customStateProps: {
          sections: [mockSectionConnection],
        },
      });
    });

    it('renders the expected number of sections', () => {
      expect(findAllSections().length).toBe(1);
    });

    it('renders title, description and the correct dynamic component', () => {
      const connectionSection = findConnectionSection();

      expect(connectionSection.find('h4').text()).toBe(mockSectionConnection.title);
      expect(connectionSection.find('p').text()).toBe(mockSectionConnection.description);
      expect(findGlBadge().exists()).toBe(false);
      expect(findConnectionSectionComponent().exists()).toBe(true);
    });

    it('renders GlBadge when `plan` is present', () => {
      createComponent({
        customStateProps: {
          sections: [mockSectionConnection, mockSectionJiraIssues],
        },
      });

      expect(findGlBadge().exists()).toBe(true);
      expect(findGlBadge().text()).toMatchInterpolatedText(billingPlanNames[billingPlans.PREMIUM]);
    });

    it('passes only fields with section type', () => {
      const sectionFields = [
        { name: 'username', type: 'text', section: mockSectionConnection.type },
        { name: 'API token', type: 'password', section: mockSectionConnection.type },
      ];

      const nonSectionFields = [
        { name: 'branch', type: 'text' },
        { name: 'labels', type: 'select' },
      ];

      createComponent({
        customStateProps: {
          sections: [mockSectionConnection],
          fields: [...sectionFields, ...nonSectionFields],
        },
      });

      expect(findConnectionSectionComponent().props('fields')).toEqual(sectionFields);
    });

    describe.each`
      formActive | novalidate
      ${true}    | ${undefined}
      ${false}   | ${'true'}
    `(
      'when `toggle-integration-active` is emitted with $formActive',
      ({ formActive, novalidate }) => {
        beforeEach(() => {
          createComponent({
            customStateProps: {
              sections: [mockSectionConnection],
              showActive: true,
              initialActivated: false,
            },
          });

          findConnectionSectionComponent().vm.$emit('toggle-integration-active', formActive);
        });

        it(`sets noValidate to ${novalidate}`, () => {
          expect(findGlForm().attributes('novalidate')).toBe(novalidate);
        });
      },
    );

    describe('when IntegrationSectionConnection emits `request-jira-issue-types` event', () => {
      beforeEach(() => {
        jest.spyOn(document, 'querySelector').mockReturnValue(document.createElement('form'));

        createComponent({
          customStateProps: {
            sections: [mockSectionConnection],
            testPath: '/test',
          },
          mountFn: mountExtended,
        });

        findConnectionSectionComponent().vm.$emit('request-jira-issue-types');
      });

      it('dispatches `requestJiraIssueTypes` action', () => {
        expect(dispatch).toHaveBeenCalledWith('requestJiraIssueTypes', expect.any(FormData));
      });
    });
  });

  describe('ActiveCheckbox', () => {
    describe.each`
      showActive
      ${true}
      ${false}
    `('when `showActive` is $showActive', ({ showActive }) => {
      it(`${showActive ? 'renders' : 'does not render'} ActiveCheckbox`, () => {
        createComponent({
          customStateProps: {
            showActive,
          },
        });

        expect(findActiveCheckbox().exists()).toBe(showActive);
      });
    });

    describe.each`
      formActive | novalidate
      ${true}    | ${undefined}
      ${false}   | ${'true'}
    `(
      'when `toggle-integration-active` is emitted with $formActive',
      ({ formActive, novalidate }) => {
        beforeEach(() => {
          createComponent({
            customStateProps: {
              showActive: true,
              initialActivated: false,
            },
          });

          findActiveCheckbox().vm.$emit('toggle-integration-active', formActive);
        });

        it(`sets noValidate to ${novalidate}`, () => {
          expect(findGlForm().attributes('novalidate')).toBe(novalidate);
        });
      },
    );
  });

  describe('when `save` button is clicked', () => {
    describe('buttons', () => {
      beforeEach(async () => {
        createComponent({
          customStateProps: {
            showActive: true,
            canTest: true,
            initialActivated: true,
          },
          mountFn: mountExtended,
        });

        await findProjectSaveButton().vm.$emit('click', new Event('click'));
      });

      it('sets save button `loading` prop to `true`', () => {
        expect(findProjectSaveButton().props('loading')).toBe(true);
      });

      it('sets test button `disabled` prop to `true`', () => {
        expect(findTestButton().props('disabled')).toBe(true);
      });
    });

    describe.each`
      checkValidityReturn | integrationActive
      ${true}             | ${false}
      ${true}             | ${true}
      ${false}            | ${false}
    `(
      'when form is valid (checkValidity returns $checkValidityReturn and integrationActive is $integrationActive)',
      ({ integrationActive, checkValidityReturn }) => {
        beforeEach(async () => {
          createComponent({
            customStateProps: {
              showActive: true,
              canTest: true,
              initialActivated: integrationActive,
            },
            mountFn: mountExtended,
          });
          jest.spyOn(findGlForm().element, 'submit');
          jest.spyOn(findGlForm().element, 'checkValidity').mockReturnValue(checkValidityReturn);

          await findProjectSaveButton().vm.$emit('click', new Event('click'));
        });

        it('submit form', () => {
          expect(findGlForm().element.submit).toHaveBeenCalledTimes(1);
        });
      },
    );

    describe('when form is invalid (checkValidity returns false and integrationActive is true)', () => {
      beforeEach(async () => {
        createComponent({
          customStateProps: {
            showActive: true,
            canTest: true,
            initialActivated: true,
            fields: [mockField],
          },
          mountFn: mountExtended,
        });
        jest.spyOn(findGlForm().element, 'submit');
        jest.spyOn(findGlForm().element, 'checkValidity').mockReturnValue(false);

        await findProjectSaveButton().vm.$emit('click', new Event('click'));
      });

      it('does not submit form', () => {
        expect(findGlForm().element.submit).not.toHaveBeenCalled();
      });

      it('sets save button `loading` prop to `false`', () => {
        expect(findProjectSaveButton().props('loading')).toBe(false);
      });

      it('sets test button `disabled` prop to `false`', () => {
        expect(findTestButton().props('disabled')).toBe(false);
      });

      it('sets `isValidated` props on form fields', () => {
        expect(findDynamicField().props('isValidated')).toBe(true);
      });
    });
  });

  describe('when `test` button is clicked', () => {
    describe('when form is invalid', () => {
      it('sets `isValidated` props on form fields', async () => {
        createComponent({
          customStateProps: {
            showActive: true,
            canTest: true,
            fields: [mockField],
          },
          mountFn: mountExtended,
        });
        jest.spyOn(findGlForm().element, 'checkValidity').mockReturnValue(false);

        await findTestButton().vm.$emit('click', new Event('click'));

        expect(findDynamicField().props('isValidated')).toBe(true);
      });
    });

    describe('when form is valid', () => {
      const mockTestPath = '/test';

      beforeEach(() => {
        createComponent({
          customStateProps: {
            showActive: true,
            canTest: true,
            testPath: mockTestPath,
          },
          mountFn: mountExtended,
        });
        jest.spyOn(findGlForm().element, 'checkValidity').mockReturnValue(true);
      });

      describe('buttons', () => {
        beforeEach(async () => {
          await findTestButton().vm.$emit('click', new Event('click'));
        });

        it('sets test button `loading` prop to `true`', () => {
          expect(findTestButton().props('loading')).toBe(true);
        });

        it('sets save button `disabled` prop to `true`', () => {
          expect(findProjectSaveButton().props('disabled')).toBe(true);
        });
      });

      describe.each`
        scenario                                                | replyStatus                         | errorMessage   | serviceResponse | expectToast                           | expectSentry
        ${'when "test settings" request fails'}                 | ${httpStatus.INTERNAL_SERVER_ERROR} | ${undefined}   | ${undefined}    | ${I18N_DEFAULT_ERROR_MESSAGE}         | ${true}
        ${'when "test settings" returns an error'}              | ${httpStatus.OK}                    | ${'an error'}  | ${undefined}    | ${'an error'}                         | ${false}
        ${'when "test settings" returns an error with details'} | ${httpStatus.OK}                    | ${'an error.'} | ${'extra info'} | ${'an error. extra info'}             | ${false}
        ${'when "test settings" succeeds'}                      | ${httpStatus.OK}                    | ${undefined}   | ${undefined}    | ${I18N_SUCCESSFUL_CONNECTION_MESSAGE} | ${false}
      `(
        '$scenario',
        ({ replyStatus, errorMessage, serviceResponse, expectToast, expectSentry }) => {
          beforeEach(async () => {
            mockAxios.onPut(mockTestPath).replyOnce(replyStatus, {
              error: Boolean(errorMessage),
              message: errorMessage,
              service_response: serviceResponse,
            });

            await findTestButton().vm.$emit('click', new Event('click'));
            await waitForPromises();
          });

          it(`calls toast with '${expectToast}'`, () => {
            expect(mockToastShow).toHaveBeenCalledWith(expectToast);
          });

          it('sets `loading` prop of test button to `false`', () => {
            expect(findTestButton().props('loading')).toBe(false);
          });

          it('sets save button `disabled` prop to `false`', () => {
            expect(findProjectSaveButton().props('disabled')).toBe(false);
          });

          it(`${expectSentry ? 'does' : 'does not'} capture exception in Sentry`, () => {
            expect(Sentry.captureException).toHaveBeenCalledTimes(expectSentry ? 1 : 0);
          });
        },
      );
    });
  });

  describe('when `reset-confirmation-modal` emits `reset` event', () => {
    const mockResetPath = '/reset';

    describe('buttons', () => {
      beforeEach(async () => {
        createComponent({
          customStateProps: {
            integrationLevel: integrationLevels.GROUP,
            canTest: true,
            resetPath: mockResetPath,
          },
        });

        await findResetConfirmationModal().vm.$emit('reset');
      });

      it('sets reset button `loading` prop to `true`', () => {
        expect(findResetButton().props('loading')).toBe(true);
      });

      it('sets other button `disabled` props to `true`', () => {
        expect(findInstanceOrGroupSaveButton().props('disabled')).toBe(true);
        expect(findTestButton().props('disabled')).toBe(true);
      });
    });

    describe('when "reset settings" request fails', () => {
      beforeEach(async () => {
        mockAxios.onPost(mockResetPath).replyOnce(httpStatus.INTERNAL_SERVER_ERROR);
        createComponent({
          customStateProps: {
            integrationLevel: integrationLevels.GROUP,
            canTest: true,
            resetPath: mockResetPath,
          },
        });

        await findResetConfirmationModal().vm.$emit('reset');
        await waitForPromises();
      });

      it('displays a toast', () => {
        expect(mockToastShow).toHaveBeenCalledWith(I18N_DEFAULT_ERROR_MESSAGE);
      });

      it('captures exception in Sentry', () => {
        expect(Sentry.captureException).toHaveBeenCalledTimes(1);
      });

      it('sets reset button `loading` prop to `false`', () => {
        expect(findResetButton().props('loading')).toBe(false);
      });

      it('sets button `disabled` props to `false`', () => {
        expect(findInstanceOrGroupSaveButton().props('disabled')).toBe(false);
        expect(findTestButton().props('disabled')).toBe(false);
      });
    });

    describe('when "reset settings" succeeds', () => {
      beforeEach(async () => {
        mockAxios.onPost(mockResetPath).replyOnce(httpStatus.OK);
        createComponent({
          customStateProps: {
            integrationLevel: integrationLevels.GROUP,
            resetPath: mockResetPath,
          },
        });

        await findResetConfirmationModal().vm.$emit('reset');
        await waitForPromises();
      });

      it('calls `refreshCurrentPage`', () => {
        expect(refreshCurrentPage).toHaveBeenCalledTimes(1);
      });
    });
  });
});
