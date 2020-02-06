import { mount } from '@vue/test-utils';
import { getJSONFixture } from 'helpers/fixtures';
import Summary from '~/pipelines/components/test_reports/test_summary.vue';

describe('Test reports summary', () => {
  let wrapper;

  const {
    test_suites: [testSuite],
  } = getJSONFixture('pipelines/test_report.json');

  const backButton = () => wrapper.find('.js-back-button');
  const totalTests = () => wrapper.find('.js-total-tests');
  const failedTests = () => wrapper.find('.js-failed-tests');
  const erroredTests = () => wrapper.find('.js-errored-tests');
  const successRate = () => wrapper.find('.js-success-rate');
  const duration = () => wrapper.find('.js-duration');

  const defaultProps = {
    report: testSuite,
    showBack: false,
  };

  const createComponent = props => {
    wrapper = mount(Summary, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  describe('should not render', () => {
    beforeEach(() => {
      createComponent();
    });

    it('a back button by default', () => {
      expect(backButton().exists()).toBe(false);
    });
  });

  describe('should render', () => {
    beforeEach(() => {
      createComponent();
    });

    it('a back button and emit on-back-click event', () => {
      createComponent({
        showBack: true,
      });

      expect(backButton().exists()).toBe(true);
    });
  });

  describe('when a report is supplied', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays the correct total', () => {
      expect(totalTests().text()).toBe('4 jobs');
    });

    it('displays the correct failure count', () => {
      expect(failedTests().text()).toBe('2 failures');
    });

    it('displays the correct error count', () => {
      expect(erroredTests().text()).toBe('0 errors');
    });

    it('calculates and displays percentages correctly', () => {
      expect(successRate().text()).toBe('50% success rate');
    });

    it('displays the correctly formatted duration', () => {
      expect(duration().text()).toBe('00:00:00');
    });
  });

  describe('success percentage calculation', () => {
    it.each`
      name                                     | successCount | totalCount | result
      ${'displays 0 when there are no tests'}  | ${0}         | ${0}       | ${'0'}
      ${'displays whole number when possible'} | ${10}        | ${50}      | ${'20'}
      ${'rounds to 0.01'}                      | ${1}         | ${16604}   | ${'0.01'}
      ${'correctly rounds to 50'}              | ${8302}      | ${16604}   | ${'50'}
      ${'rounds down for large close numbers'} | ${16603}     | ${16604}   | ${'99.99'}
      ${'correctly displays 100'}              | ${16604}     | ${16604}   | ${'100'}
    `('$name', ({ successCount, totalCount, result }) => {
      createComponent({
        report: {
          success_count: successCount,
          total_count: totalCount,
        },
      });

      expect(successRate().text()).toBe(`${result}% success rate`);
    });
  });
});
