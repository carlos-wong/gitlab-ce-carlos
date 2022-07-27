import { nextTick } from 'vue';
import MockAdapter from 'axios-mock-adapter';
import testReportExtension from '~/vue_merge_request_widget/extensions/test_report';
import { i18n } from '~/vue_merge_request_widget/extensions/test_report/constants';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { trimText } from 'helpers/text_helper';
import waitForPromises from 'helpers/wait_for_promises';
import axios from '~/lib/utils/axios_utils';
import extensionsContainer from '~/vue_merge_request_widget/components/extensions/container';
import { registerExtension } from '~/vue_merge_request_widget/components/extensions';
import httpStatusCodes from '~/lib/utils/http_status';
import TestCaseDetails from '~/pipelines/components/test_reports/test_case_details.vue';

import { failedReport } from 'jest/reports/mock_data/mock_data';
import mixedResultsTestReports from 'jest/reports/mock_data/new_and_fixed_failures_report.json';
import newErrorsTestReports from 'jest/reports/mock_data/new_errors_report.json';
import newFailedTestReports from 'jest/reports/mock_data/new_failures_report.json';
import successTestReports from 'jest/reports/mock_data/no_failures_report.json';
import resolvedFailures from 'jest/reports/mock_data/resolved_failures.json';
import recentFailures from 'jest/reports/mock_data/recent_failures_report.json';

const reportWithParsingErrors = failedReport;
reportWithParsingErrors.suites[0].suite_errors = {
  head: 'JUnit XML parsing failed: 2:24: FATAL: attributes construct error',
  base: 'JUnit data parsing failed: string not matched',
};

describe('Test report extension', () => {
  let wrapper;
  let mock;

  registerExtension(testReportExtension);

  const endpoint = '/root/repo/-/merge_requests/4/test_reports.json';

  const mockApi = (statusCode, data = mixedResultsTestReports) => {
    mock.onGet(endpoint).reply(statusCode, data);
  };

  const findToggleCollapsedButton = () => wrapper.findByTestId('toggle-button');
  const findFullReportLink = () => wrapper.findByTestId('full-report-link');
  const findCopyFailedSpecsBtn = () => wrapper.findByTestId('copy-failed-specs-btn');
  const findAllExtensionListItems = () => wrapper.findAllByTestId('extension-list-item');
  const findModal = () => wrapper.find(TestCaseDetails);

  const createComponent = () => {
    wrapper = mountExtended(extensionsContainer, {
      propsData: {
        mr: {
          testResultsPath: endpoint,
          headBlobPath: 'head/blob/path',
          pipeline: { path: 'pipeline/path' },
        },
      },
    });
  };

  const createExpandedWidgetWithData = async (data = mixedResultsTestReports) => {
    mockApi(httpStatusCodes.OK, data);
    createComponent();
    await waitForPromises();
    findToggleCollapsedButton().trigger('click');
    await waitForPromises();
  };

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    wrapper.destroy();
    mock.restore();
  });

  describe('summary', () => {
    it('displays loading state initially', () => {
      mockApi(httpStatusCodes.OK);
      createComponent();

      expect(wrapper.text()).toContain(i18n.loading);
    });

    it('with a 204 response, continues to display loading state', async () => {
      mockApi(httpStatusCodes.NO_CONTENT, '');
      createComponent();

      await waitForPromises();

      expect(wrapper.text()).toContain(i18n.loading);
    });

    it('with an error response, displays failed to load text', async () => {
      mockApi(httpStatusCodes.INTERNAL_SERVER_ERROR);
      createComponent();

      await waitForPromises();

      expect(wrapper.text()).toContain(i18n.error);
    });

    it.each`
      description                 | mockData                   | expectedResult
      ${'mixed test results'}     | ${mixedResultsTestReports} | ${'Test summary: 2 failed and 2 fixed test results, 11 total tests'}
      ${'unchanged test results'} | ${successTestReports}      | ${'Test summary: no changed test results, 11 total tests'}
      ${'tests with errors'}      | ${newErrorsTestReports}    | ${'Test summary: 2 errors, 11 total tests'}
      ${'failed test results'}    | ${newFailedTestReports}    | ${'Test summary: 2 failed, 11 total tests'}
      ${'resolved failures'}      | ${resolvedFailures}        | ${'Test summary: 4 fixed test results, 11 total tests'}
    `('displays summary text for $description', async ({ mockData, expectedResult }) => {
      mockApi(httpStatusCodes.OK, mockData);
      createComponent();

      await waitForPromises();

      expect(wrapper.text()).toContain(expectedResult);
    });

    it('displays report level recently failed count', async () => {
      mockApi(httpStatusCodes.OK, recentFailures);
      createComponent();

      await waitForPromises();

      expect(wrapper.text()).toContain(
        '2 out of 3 failed tests have failed more than once in the last 14 days',
      );
    });

    it('displays a link to the full report', async () => {
      mockApi(httpStatusCodes.OK);
      createComponent();

      await waitForPromises();

      expect(findFullReportLink().text()).toBe('Full report');
      expect(findFullReportLink().attributes('href')).toBe('pipeline/path/test_report');
    });

    it('hides copy failed tests button when there are no failing tests', async () => {
      mockApi(httpStatusCodes.OK);
      createComponent();

      await waitForPromises();

      expect(findCopyFailedSpecsBtn().exists()).toBe(false);
    });

    it('displays copy failed tests button when there are failing tests', async () => {
      mockApi(httpStatusCodes.OK, newFailedTestReports);
      createComponent();

      await waitForPromises();

      expect(findCopyFailedSpecsBtn().exists()).toBe(true);
      expect(findCopyFailedSpecsBtn().text()).toBe(i18n.copyFailedSpecs);
      expect(findCopyFailedSpecsBtn().attributes('data-clipboard-text')).toBe(
        'spec/file_1.rb spec/file_2.rb',
      );
    });

    it('copy failed tests button updates tooltip text when clicked', async () => {
      mockApi(httpStatusCodes.OK, newFailedTestReports);
      createComponent();

      await waitForPromises();

      // original tooltip shows up
      expect(findCopyFailedSpecsBtn().attributes()).toMatchObject({
        title: i18n.copyFailedSpecsTooltip,
      });

      await findCopyFailedSpecsBtn().trigger('click');

      // tooltip text is replaced for 1 second
      expect(findCopyFailedSpecsBtn().attributes()).toMatchObject({
        title: 'Copied',
      });

      jest.runAllTimers();
      await nextTick();

      // tooltip reverts back to original string
      expect(findCopyFailedSpecsBtn().attributes()).toMatchObject({
        title: i18n.copyFailedSpecsTooltip,
      });
    });

    it('shows an error when a suite has a parsing error', async () => {
      mockApi(httpStatusCodes.OK, reportWithParsingErrors);
      createComponent();

      await waitForPromises();

      expect(wrapper.text()).toContain(i18n.error);
    });
  });

  describe('expanded data', () => {
    it('displays summary for each suite', async () => {
      await createExpandedWidgetWithData();

      expect(trimText(findAllExtensionListItems().at(0).text())).toContain(
        'rspec:pg: 1 failed and 2 fixed test results, 8 total tests',
      );
      expect(trimText(findAllExtensionListItems().at(1).text())).toContain(
        'java ant: 1 failed, 3 total tests',
      );
    });

    it('displays suite parsing errors', async () => {
      await createExpandedWidgetWithData(reportWithParsingErrors);

      const suiteText = trimText(findAllExtensionListItems().at(0).text());

      expect(suiteText).toContain(
        'Head report parsing error: JUnit XML parsing failed: 2:24: FATAL: attributes construct error',
      );
      expect(suiteText).toContain(
        'Base report parsing error: JUnit data parsing failed: string not matched',
      );
    });

    it('displays suite level recently failed count', async () => {
      await createExpandedWidgetWithData(recentFailures);

      expect(trimText(findAllExtensionListItems().at(0).text())).toContain(
        '1 out of 2 failed tests has failed more than once in the last 14 days',
      );
      expect(trimText(findAllExtensionListItems().at(1).text())).toContain(
        '1 out of 1 failed test has failed more than once in the last 14 days',
      );
    });

    it('displays the list of failed and fixed tests', async () => {
      await createExpandedWidgetWithData();

      const firstSuite = trimText(findAllExtensionListItems().at(0).text());
      const secondSuite = trimText(findAllExtensionListItems().at(1).text());

      expect(firstSuite).toContain('Test#subtract when a is 2 and b is 1 returns correct result');
      expect(firstSuite).toContain('Test#sum when a is 1 and b is 2 returns summary');
      expect(firstSuite).toContain('Test#sum when a is 100 and b is 200 returns summary');

      expect(secondSuite).toContain('sumTest');
    });

    it('displays the test level recently failed count', async () => {
      await createExpandedWidgetWithData(recentFailures);

      expect(trimText(findAllExtensionListItems().at(0).text())).toContain(
        'Failed 8 times in main in the last 14 days',
      );
    });
  });

  describe('modal link', () => {
    beforeEach(async () => {
      await createExpandedWidgetWithData();

      wrapper.findByTestId('modal-link').trigger('click');
    });

    it('opens a modal to display test case details', () => {
      expect(findModal().exists()).toBe(true);
      expect(findModal().props('testCase')).toMatchObject(
        mixedResultsTestReports.suites[0].new_failures[0],
      );
    });
  });
});
