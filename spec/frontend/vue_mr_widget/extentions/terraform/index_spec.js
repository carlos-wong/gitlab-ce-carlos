import MockAdapter from 'axios-mock-adapter';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import api from '~/api';
import axios from '~/lib/utils/axios_utils';
import Poll from '~/lib/utils/poll';
import extensionsContainer from '~/vue_merge_request_widget/components/extensions/container';
import { registerExtension } from '~/vue_merge_request_widget/components/extensions';
import terraformExtension from '~/vue_merge_request_widget/extensions/terraform';
import {
  plans,
  validPlanWithName,
  validPlanWithoutName,
  invalidPlanWithName,
  invalidPlanWithoutName,
} from '../../components/terraform/mock_data';

jest.mock('~/api.js');

describe('Terraform extension', () => {
  let wrapper;
  let mock;

  const endpoint = '/path/to/terraform/report.json';
  const successStatusCode = 200;
  const errorStatusCode = 500;

  const findListItem = (at) => wrapper.findAllByTestId('extension-list-item').at(at);

  registerExtension(terraformExtension);

  const mockPollingApi = (response, body, header) => {
    mock.onGet(endpoint).reply(response, body, header);
  };

  const createComponent = () => {
    wrapper = mountExtended(extensionsContainer, {
      propsData: {
        mr: {
          terraformReportsPath: endpoint,
        },
      },
    });
    return axios.waitForAll();
  };

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    wrapper.destroy();
    mock.restore();
  });

  describe('summary', () => {
    describe('while loading', () => {
      const loadingText = 'Loading Terraform reports...';
      it('should render loading text', async () => {
        mockPollingApi(successStatusCode, plans, {});
        createComponent();

        expect(wrapper.text()).toContain(loadingText);
        await waitForPromises();
        expect(wrapper.text()).not.toContain(loadingText);
      });
    });

    describe('when the fetching fails', () => {
      beforeEach(() => {
        mockPollingApi(errorStatusCode, null, {});
        return createComponent();
      });

      it('should generate one invalid plan and render correct summary text', () => {
        expect(wrapper.text()).toContain('1 Terraform report failed to generate');
      });
    });

    describe('when the fetching succeeds', () => {
      describe.each`
        responseType                       | response                                                                    | summaryTitle                                              | summarySubtitle
        ${'1 invalid report'}              | ${{ 0: invalidPlanWithName }}                                               | ${'1 Terraform report failed to generate'}                | ${''}
        ${'2 valid reports'}               | ${{ 0: validPlanWithName, 1: validPlanWithName }}                           | ${'2 Terraform reports were generated in your pipelines'} | ${''}
        ${'1 valid and 2 invalid reports'} | ${{ 0: validPlanWithName, 1: invalidPlanWithName, 2: invalidPlanWithName }} | ${'Terraform report was generated in your pipelines'}     | ${'2 Terraform reports failed to generate'}
      `('and received $responseType', ({ response, summaryTitle, summarySubtitle }) => {
        beforeEach(async () => {
          mockPollingApi(successStatusCode, response, {});
          return createComponent();
        });

        it(`should render correct summary text`, () => {
          expect(wrapper.text()).toContain(summaryTitle);

          if (summarySubtitle) {
            expect(wrapper.text()).toContain(summarySubtitle);
          }
        });
      });
    });
  });

  describe('expanded data', () => {
    beforeEach(async () => {
      mockPollingApi(successStatusCode, plans, {});
      await createComponent();

      wrapper.findByTestId('toggle-button').trigger('click');
    });

    describe.each`
      reportType                          | title                                                                     | subtitle                                                                                                                                                  | logLink                            | lineNumber
      ${'a valid report with name'}       | ${`The job ${validPlanWithName.job_name} generated a report.`}            | ${`Reported Resource Changes: ${validPlanWithName.create} to add, ${validPlanWithName.update} to change, ${validPlanWithName.delete} to delete`}          | ${validPlanWithName.job_path}      | ${0}
      ${'a valid report without name'}    | ${'A Terraform report was generated in your pipelines.'}                  | ${`Reported Resource Changes: ${validPlanWithoutName.create} to add, ${validPlanWithoutName.update} to change, ${validPlanWithoutName.delete} to delete`} | ${validPlanWithoutName.job_path}   | ${1}
      ${'an invalid report with name'}    | ${`The job ${invalidPlanWithName.job_name} failed to generate a report.`} | ${'Generating the report caused an error.'}                                                                                                               | ${invalidPlanWithName.job_path}    | ${2}
      ${'an invalid report without name'} | ${'A Terraform report failed to generate.'}                               | ${'Generating the report caused an error.'}                                                                                                               | ${invalidPlanWithoutName.job_path} | ${3}
    `('renders correct text for $reportType', ({ title, subtitle, logLink, lineNumber }) => {
      it('renders correct text', () => {
        expect(findListItem(lineNumber).text()).toContain(title);
        expect(findListItem(lineNumber).text()).toContain(subtitle);
      });

      it(`${logLink ? 'renders' : "doesn't render"} the log link`, () => {
        const logText = 'Full log';
        if (logLink) {
          expect(
            findListItem(lineNumber)
              .find('[data-testid="extension-actions-button"]')
              .attributes('href'),
          ).toBe(logLink);
        } else {
          expect(findListItem(lineNumber).text()).not.toContain(logText);
        }
      });
    });

    it('responds with the correct telemetry when the deeply nested "Full log" link is clicked', () => {
      api.trackRedisHllUserEvent.mockClear();
      api.trackRedisCounterEvent.mockClear();

      findListItem(0).find('[data-testid="extension-actions-button"]').trigger('click');

      expect(api.trackRedisHllUserEvent).toHaveBeenCalledTimes(1);
      expect(api.trackRedisHllUserEvent).toHaveBeenCalledWith(
        'i_code_review_merge_request_widget_terraform_click_full_report',
      );
      expect(api.trackRedisCounterEvent).toHaveBeenCalledTimes(1);
      expect(api.trackRedisCounterEvent).toHaveBeenCalledWith(
        'i_code_review_merge_request_widget_terraform_count_click_full_report',
      );
    });
  });

  describe('polling', () => {
    let pollRequest;

    beforeEach(() => {
      pollRequest = jest.spyOn(Poll.prototype, 'makeRequest');
    });

    afterEach(() => {
      pollRequest.mockRestore();
    });

    describe('successful poll', () => {
      beforeEach(() => {
        mockPollingApi(successStatusCode, plans, {});

        return createComponent();
      });

      it('does not make additional requests after poll is successful', () => {
        expect(pollRequest).toHaveBeenCalledTimes(1);
      });
    });

    describe('polling fails', () => {
      beforeEach(() => {
        mockPollingApi(errorStatusCode, null, {});
        return createComponent();
      });

      it('generates one broken plan', () => {
        expect(wrapper.text()).toContain('1 Terraform report failed to generate');
      });

      it('does not make additional requests after poll is unsuccessful', () => {
        expect(pollRequest).toHaveBeenCalledTimes(1);
      });
    });
  });
});
