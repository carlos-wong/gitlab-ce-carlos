import { mount } from '@vue/test-utils';
import Vue from 'vue';
import Vuex from 'vuex';
import CodequalityIssueBody from '~/reports/codequality_report/components/codequality_issue_body.vue';
import GroupedCodequalityReportsApp from '~/reports/codequality_report/grouped_codequality_reports_app.vue';
import { getStoreConfig } from '~/reports/codequality_report/store';
import { STATUS_NOT_FOUND } from '~/reports/constants';
import { parsedReportIssues } from './mock_data';

Vue.use(Vuex);

describe('Grouped code quality reports app', () => {
  let wrapper;
  let mockStore;

  const PATHS = {
    codequalityHelpPath: 'codequality_help.html',
    baseBlobPath: 'base/blob/path/',
    headBlobPath: 'head/blob/path/',
  };

  const mountComponent = (props = {}) => {
    wrapper = mount(GroupedCodequalityReportsApp, {
      store: mockStore,
      propsData: {
        ...PATHS,
        ...props,
      },
    });
  };

  const findWidget = () => wrapper.find('.js-codequality-widget');
  const findIssueBody = () => wrapper.find(CodequalityIssueBody);

  beforeEach(() => {
    const { state, ...storeConfig } = getStoreConfig();
    mockStore = new Vuex.Store({
      ...storeConfig,
      actions: {
        setPaths: () => {},
        fetchReports: () => {},
      },
      state: {
        ...state,
        ...PATHS,
      },
    });

    mountComponent();
  });

  afterEach(() => {
    wrapper.destroy();
  });

  describe('when it is loading reports', () => {
    beforeEach(() => {
      mockStore.state.isLoading = true;
    });

    it('should render loading text', () => {
      expect(findWidget().text()).toEqual('Loading Code quality report');
    });
  });

  describe('when base and head reports are loaded and compared', () => {
    describe('with no issues', () => {
      beforeEach(() => {
        mockStore.state.newIssues = [];
        mockStore.state.resolvedIssues = [];
      });

      it('renders no changes text', () => {
        expect(findWidget().text()).toEqual('No changes to code quality');
      });
    });

    describe('with issues', () => {
      describe('with new issues', () => {
        beforeEach(() => {
          mockStore.state.newIssues = parsedReportIssues.newIssues;
          mockStore.state.resolvedIssues = [];
        });

        it('renders summary text', () => {
          expect(findWidget().text()).toContain('Code quality degraded');
        });

        it('renders custom codequality issue body', () => {
          expect(findIssueBody().props('issue')).toEqual(parsedReportIssues.newIssues[0]);
        });
      });

      describe('with resolved issues', () => {
        beforeEach(() => {
          mockStore.state.newIssues = [];
          mockStore.state.resolvedIssues = parsedReportIssues.resolvedIssues;
        });

        it('renders summary text', () => {
          expect(findWidget().text()).toContain('Code quality improved');
        });

        it('renders custom codequality issue body', () => {
          expect(findIssueBody().props('issue')).toEqual(parsedReportIssues.resolvedIssues[0]);
        });
      });

      describe('with new and resolved issues', () => {
        beforeEach(() => {
          mockStore.state.newIssues = parsedReportIssues.newIssues;
          mockStore.state.resolvedIssues = parsedReportIssues.resolvedIssues;
        });

        it('renders summary text', () => {
          expect(findWidget().text()).toContain(
            'Code quality scanning detected 2 changes in merged results',
          );
        });

        it('renders custom codequality issue body', () => {
          expect(findIssueBody().props('issue')).toEqual(parsedReportIssues.newIssues[0]);
        });
      });
    });
  });

  describe('on error', () => {
    beforeEach(() => {
      mockStore.state.hasError = true;
    });

    it('renders error text', () => {
      expect(findWidget().text()).toContain('Failed to load Code quality report');
    });

    it('does not render a help icon', () => {
      expect(findWidget().find('[data-testid="question-o-icon"]').exists()).toBe(false);
    });

    describe('when base report was not found', () => {
      beforeEach(() => {
        mockStore.state.status = STATUS_NOT_FOUND;
      });

      it('renders a help icon with more information', () => {
        expect(findWidget().find('[data-testid="question-o-icon"]').exists()).toBe(true);
      });
    });
  });
});
