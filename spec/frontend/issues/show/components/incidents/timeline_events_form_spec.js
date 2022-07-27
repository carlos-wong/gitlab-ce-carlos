import VueApollo from 'vue-apollo';
import Vue, { nextTick } from 'vue';
import { GlDatepicker } from '@gitlab/ui';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import IncidentTimelineEventForm from '~/issues/show/components/incidents/timeline_events_form.vue';
import createTimelineEventMutation from '~/issues/show/components/incidents/graphql/queries/create_timeline_event.mutation.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import { createAlert } from '~/flash';
import { useFakeDate } from 'helpers/fake_date';
import { timelineEventsCreateEventResponse, timelineEventsCreateEventError } from './mock_data';

Vue.use(VueApollo);

jest.mock('~/flash');

const addEventResponse = jest.fn().mockResolvedValue(timelineEventsCreateEventResponse);

function createMockApolloProvider(response = addEventResponse) {
  const requestHandlers = [[createTimelineEventMutation, response]];
  return createMockApollo(requestHandlers);
}

describe('Timeline events form', () => {
  // July 8 2020
  useFakeDate(2020, 6, 8);
  let wrapper;

  const mountComponent = ({ mockApollo, mountMethod = shallowMountExtended, stubs }) => {
    wrapper = mountMethod(IncidentTimelineEventForm, {
      propsData: {
        hasTimelineEvents: true,
      },
      provide: {
        fullPath: 'group/project',
        issuableId: '1',
      },
      apolloProvider: mockApollo,
      stubs,
    });
  };

  afterEach(() => {
    addEventResponse.mockReset();
    createAlert.mockReset();
    if (wrapper) {
      wrapper.destroy();
    }
  });

  const findSubmitButton = () => wrapper.findByText('Save');
  const findSubmitAndAddButton = () => wrapper.findByText('Save and add another event');
  const findCancelButton = () => wrapper.findByText('Cancel');
  const findDatePicker = () => wrapper.findComponent(GlDatepicker);
  const findDatePickerInput = () => wrapper.findByTestId('input-datepicker');
  const findHourInput = () => wrapper.findByTestId('input-hours');
  const findMinuteInput = () => wrapper.findByTestId('input-minutes');
  const setDatetime = () => {
    findDatePicker().vm.$emit('input', new Date('2021-08-12'));
    findHourInput().vm.$emit('input', 5);
    findMinuteInput().vm.$emit('input', 45);
  };

  const submitForm = async () => {
    findSubmitButton().trigger('click');
    await waitForPromises();
  };
  const submitFormAndAddAnother = async () => {
    findSubmitAndAddButton().trigger('click');
    await waitForPromises();
  };
  const cancelForm = async () => {
    findCancelButton().trigger('click');
    await waitForPromises();
  };

  describe('form button behaviour', () => {
    const closeFormEvent = { 'hide-incident-timeline-event-form': [[]] };
    beforeEach(() => {
      mountComponent({ mockApollo: createMockApolloProvider(), mountMethod: mountExtended });
    });

    it('should close the form on submit', async () => {
      await submitForm();
      expect(wrapper.emitted()).toEqual(closeFormEvent);
    });

    it('should not close the form on "submit and add another"', async () => {
      await submitFormAndAddAnother();
      expect(wrapper.emitted()).toEqual({});
    });

    it('should close the form on cancel', async () => {
      await cancelForm();
      expect(wrapper.emitted()).toEqual(closeFormEvent);
    });

    it('should clear the form', async () => {
      setDatetime();
      await nextTick();

      expect(findDatePickerInput().element.value).toBe('2021-08-12');
      expect(findHourInput().element.value).toBe('5');
      expect(findMinuteInput().element.value).toBe('45');

      wrapper.vm.clear();
      await nextTick();

      expect(findDatePickerInput().element.value).toBe('2020-07-08');
      expect(findHourInput().element.value).toBe('0');
      expect(findMinuteInput().element.value).toBe('0');
    });
  });

  describe('addTimelineEventQuery', () => {
    const expectedData = {
      input: {
        incidentId: 'gid://gitlab/Issue/1',
        note: '',
        occurredAt: '2020-07-08T00:00:00.000Z',
      },
    };

    let mockApollo;

    beforeEach(() => {
      mockApollo = createMockApolloProvider();
      mountComponent({ mockApollo, mountMethod: mountExtended });
    });

    it('should call the mutation with the right variables', async () => {
      await submitForm();

      expect(addEventResponse).toHaveBeenCalledWith(expectedData);
    });

    it('should call the mutation with user selected variables', async () => {
      const expectedUserSelectedData = {
        input: {
          ...expectedData.input,
          occurredAt: '2021-08-12T05:45:00.000Z',
        },
      };

      setDatetime();

      await nextTick();
      await submitForm();

      expect(addEventResponse).toHaveBeenCalledWith(expectedUserSelectedData);
    });
  });

  describe('error handling', () => {
    it('should show an error when submission returns an error', async () => {
      const expectedAlertArgs = {
        message: 'Error creating incident timeline event: Create error',
      };
      addEventResponse.mockResolvedValueOnce(timelineEventsCreateEventError);
      mountComponent({ mockApollo: createMockApolloProvider(), mountMethod: mountExtended });

      await submitForm();

      expect(createAlert).toHaveBeenCalledWith(expectedAlertArgs);
    });

    it('should show an error when submission fails', async () => {
      const expectedAlertArgs = {
        captureError: true,
        error: new Error(),
        message: 'Something went wrong while creating the incident timeline event.',
      };
      addEventResponse.mockRejectedValueOnce();
      mountComponent({ mockApollo: createMockApolloProvider(), mountMethod: mountExtended });

      await submitForm();

      expect(createAlert).toHaveBeenCalledWith(expectedAlertArgs);
    });
  });
});
