import Vue from 'vue';
import MockAdapter from 'axios-mock-adapter';
import Dashboard from '~/monitoring/components/dashboard.vue';
import { timeWindows, timeWindowsKeyNames } from '~/monitoring/constants';
import * as types from '~/monitoring/stores/mutation_types';
import { createStore } from '~/monitoring/stores';
import axios from '~/lib/utils/axios_utils';
import {
  metricsGroupsAPIResponse,
  mockApiEndpoint,
  environmentData,
  singleGroupResponse,
} from './mock_data';

const propsData = {
  hasMetrics: false,
  documentationPath: '/path/to/docs',
  settingsPath: '/path/to/settings',
  clustersPath: '/path/to/clusters',
  tagsPath: '/path/to/tags',
  projectPath: '/path/to/project',
  metricsEndpoint: mockApiEndpoint,
  deploymentsEndpoint: null,
  emptyGettingStartedSvgPath: '/path/to/getting-started.svg',
  emptyLoadingSvgPath: '/path/to/loading.svg',
  emptyNoDataSvgPath: '/path/to/no-data.svg',
  emptyUnableToConnectSvgPath: '/path/to/unable-to-connect.svg',
  environmentsEndpoint: '/root/hello-prometheus/environments/35',
  currentEnvironmentName: 'production',
  customMetricsAvailable: false,
  customMetricsPath: '',
  validateQueryPath: '',
};

export default propsData;

describe('Dashboard', () => {
  let DashboardComponent;
  let mock;
  let store;
  let component;

  beforeEach(() => {
    setFixtures(`
      <div class="prometheus-graphs"></div>
      <div class="layout-page"></div>
    `);

    window.gon = {
      ...window.gon,
      ee: false,
    };

    store = createStore();
    mock = new MockAdapter(axios);
    DashboardComponent = Vue.extend(Dashboard);
  });

  afterEach(() => {
    component.$destroy();
    mock.restore();
  });

  describe('no metrics are available yet', () => {
    it('shows a getting started empty state when no metrics are present', () => {
      component = new DashboardComponent({
        el: document.querySelector('.prometheus-graphs'),
        propsData: { ...propsData },
        store,
      });

      expect(component.$el.querySelector('.prometheus-graphs')).toBe(null);
      expect(component.emptyState).toEqual('gettingStarted');
    });
  });

  describe('requests information to the server', () => {
    beforeEach(() => {
      mock.onGet(mockApiEndpoint).reply(200, metricsGroupsAPIResponse);
    });

    it('shows up a loading state', done => {
      component = new DashboardComponent({
        el: document.querySelector('.prometheus-graphs'),
        propsData: { ...propsData, hasMetrics: true },
        store,
      });

      Vue.nextTick(() => {
        expect(component.emptyState).toEqual('loading');
        done();
      });
    });

    it('hides the legend when showLegend is false', done => {
      component = new DashboardComponent({
        el: document.querySelector('.prometheus-graphs'),
        propsData: {
          ...propsData,
          hasMetrics: true,
          showLegend: false,
        },
        store,
      });

      setTimeout(() => {
        expect(component.showEmptyState).toEqual(false);
        expect(component.$el.querySelector('.legend-group')).toEqual(null);
        expect(component.$el.querySelector('.prometheus-graph-group')).toBeTruthy();
        done();
      });
    });

    it('hides the group panels when showPanels is false', done => {
      component = new DashboardComponent({
        el: document.querySelector('.prometheus-graphs'),
        propsData: {
          ...propsData,
          hasMetrics: true,
          showPanels: false,
        },
        store,
      });

      setTimeout(() => {
        expect(component.showEmptyState).toEqual(false);
        expect(component.$el.querySelector('.prometheus-panel')).toEqual(null);
        expect(component.$el.querySelector('.prometheus-graph-group')).toBeTruthy();
        done();
      });
    });

    it('renders the environments dropdown with a number of environments', done => {
      component = new DashboardComponent({
        el: document.querySelector('.prometheus-graphs'),
        propsData: {
          ...propsData,
          hasMetrics: true,
          showPanels: false,
        },
        store,
      });

      component.$store.commit(
        `monitoringDashboard/${types.RECEIVE_ENVIRONMENTS_DATA_SUCCESS}`,
        environmentData,
      );
      component.$store.commit(
        `monitoringDashboard/${types.RECEIVE_METRICS_DATA_SUCCESS}`,
        singleGroupResponse,
      );

      setTimeout(() => {
        const dropdownMenuEnvironments = component.$el.querySelectorAll(
          '.js-environments-dropdown .dropdown-item',
        );

        expect(dropdownMenuEnvironments.length).toEqual(component.environments.length);
        done();
      });
    });

    it('hides the environments dropdown list when there is no environments', done => {
      component = new DashboardComponent({
        el: document.querySelector('.prometheus-graphs'),
        propsData: {
          ...propsData,
          hasMetrics: true,
          showPanels: false,
        },
        store,
      });

      component.$store.commit(`monitoringDashboard/${types.RECEIVE_ENVIRONMENTS_DATA_SUCCESS}`, []);
      component.$store.commit(
        `monitoringDashboard/${types.RECEIVE_METRICS_DATA_SUCCESS}`,
        singleGroupResponse,
      );

      Vue.nextTick()
        .then(() => {
          const dropdownMenuEnvironments = component.$el.querySelectorAll(
            '.js-environments-dropdown .dropdown-item',
          );

          expect(dropdownMenuEnvironments.length).toEqual(0);
          done();
        })
        .catch(done.fail);
    });

    it('renders the environments dropdown with a single active element', done => {
      component = new DashboardComponent({
        el: document.querySelector('.prometheus-graphs'),
        propsData: {
          ...propsData,
          hasMetrics: true,
          showPanels: false,
        },
        store,
      });

      component.$store.commit(
        `monitoringDashboard/${types.RECEIVE_ENVIRONMENTS_DATA_SUCCESS}`,
        environmentData,
      );
      component.$store.commit(
        `monitoringDashboard/${types.RECEIVE_METRICS_DATA_SUCCESS}`,
        singleGroupResponse,
      );

      Vue.nextTick()
        .then(() => {
          const dropdownItems = component.$el.querySelectorAll(
            '.js-environments-dropdown .dropdown-item[active="true"]',
          );

          expect(dropdownItems.length).toEqual(1);
          done();
        })
        .catch(done.fail);
    });

    it('hides the dropdown', done => {
      component = new DashboardComponent({
        el: document.querySelector('.prometheus-graphs'),
        propsData: {
          ...propsData,
          hasMetrics: true,
          showPanels: false,
          environmentsEndpoint: '',
        },
        store,
      });

      Vue.nextTick(() => {
        const dropdownIsActiveElement = component.$el.querySelectorAll('.environments');

        expect(dropdownIsActiveElement.length).toEqual(0);
        done();
      });
    });

    it('renders the time window dropdown with a set of options', done => {
      component = new DashboardComponent({
        el: document.querySelector('.prometheus-graphs'),
        propsData: {
          ...propsData,
          hasMetrics: true,
          showPanels: false,
        },
        store,
      });
      const numberOfTimeWindows = Object.keys(timeWindows).length;

      setTimeout(() => {
        const timeWindowDropdown = component.$el.querySelector('.js-time-window-dropdown');
        const timeWindowDropdownEls = component.$el.querySelectorAll(
          '.js-time-window-dropdown .dropdown-item',
        );

        expect(timeWindowDropdown).not.toBeNull();
        expect(timeWindowDropdownEls.length).toEqual(numberOfTimeWindows);

        done();
      });
    });

    it('fetches the metrics data with proper time window', done => {
      component = new DashboardComponent({
        el: document.querySelector('.prometheus-graphs'),
        propsData: {
          ...propsData,
          hasMetrics: true,
          showPanels: false,
        },
        store,
      });

      spyOn(component.$store, 'dispatch').and.stub();
      const getTimeDiffSpy = spyOnDependency(Dashboard, 'getTimeDiff');

      component.$store.commit(
        `monitoringDashboard/${types.SET_ENVIRONMENTS_ENDPOINT}`,
        '/environments',
      );
      component.$store.commit(
        `monitoringDashboard/${types.RECEIVE_ENVIRONMENTS_DATA_SUCCESS}`,
        environmentData,
      );

      component.$mount();

      Vue.nextTick()
        .then(() => {
          expect(component.$store.dispatch).toHaveBeenCalled();
          expect(getTimeDiffSpy).toHaveBeenCalledWith(component.selectedTimeWindow);

          done();
        })
        .catch(done.fail);
    });

    it('shows a specific time window selected from the url params', done => {
      spyOnDependency(Dashboard, 'getParameterValues').and.returnValue(['thirtyMinutes']);

      component = new DashboardComponent({
        el: document.querySelector('.prometheus-graphs'),
        propsData: { ...propsData, hasMetrics: true },
        store,
      });

      setTimeout(() => {
        const selectedTimeWindow = component.$el.querySelector('.js-time-window-dropdown .active');

        expect(selectedTimeWindow.textContent.trim()).toEqual('30 minutes');
        done();
      });
    });

    it('defaults to the eight hours time window for non valid url parameters', done => {
      spyOnDependency(Dashboard, 'getParameterValues').and.returnValue([
        '<script>alert("XSS")</script>',
      ]);

      component = new DashboardComponent({
        el: document.querySelector('.prometheus-graphs'),
        propsData: { ...propsData, hasMetrics: true },
        store,
      });

      Vue.nextTick(() => {
        expect(component.selectedTimeWindowKey).toEqual(timeWindowsKeyNames.eightHours);

        done();
      });
    });
  });

  describe('when the window resizes', () => {
    beforeEach(() => {
      mock.onGet(mockApiEndpoint).reply(200, metricsGroupsAPIResponse);
      jasmine.clock().install();
    });

    afterEach(() => {
      jasmine.clock().uninstall();
    });

    it('sets elWidth to page width when the sidebar is resized', done => {
      component = new DashboardComponent({
        el: document.querySelector('.prometheus-graphs'),
        propsData: {
          ...propsData,
          hasMetrics: true,
          showPanels: false,
        },
        store,
      });

      expect(component.elWidth).toEqual(0);

      const pageLayoutEl = document.querySelector('.layout-page');
      pageLayoutEl.classList.add('page-with-icon-sidebar');

      Vue.nextTick()
        .then(() => {
          jasmine.clock().tick(1000);
          return Vue.nextTick();
        })
        .then(() => {
          expect(component.elWidth).toEqual(pageLayoutEl.clientWidth);
          done();
        })
        .catch(done.fail);
    });
  });

  describe('external dashboard link', () => {
    beforeEach(() => {
      mock.onGet(mockApiEndpoint).reply(200, metricsGroupsAPIResponse);

      component = new DashboardComponent({
        el: document.querySelector('.prometheus-graphs'),
        propsData: {
          ...propsData,
          hasMetrics: true,
          showPanels: false,
          showTimeWindowDropdown: false,
          externalDashboardUrl: '/mockUrl',
        },
        store,
      });
    });

    it('shows the link', done => {
      setTimeout(() => {
        expect(component.$el.querySelector('.js-external-dashboard-link').innerText).toContain(
          'View full dashboard',
        );
        done();
      });
    });
  });
});
