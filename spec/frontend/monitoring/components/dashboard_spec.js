import MockAdapter from 'axios-mock-adapter';
import VueDraggable from 'vuedraggable';
import { nextTick } from 'vue';
import setWindowLocation from 'helpers/set_window_location_helper';
import { TEST_HOST } from 'helpers/test_constants';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createFlash from '~/flash';
import axios from '~/lib/utils/axios_utils';
import { ESC_KEY } from '~/lib/utils/keys';
import { objectToQuery } from '~/lib/utils/url_utility';
import Dashboard from '~/monitoring/components/dashboard.vue';
import DashboardHeader from '~/monitoring/components/dashboard_header.vue';
import DashboardPanel from '~/monitoring/components/dashboard_panel.vue';
import EmptyState from '~/monitoring/components/empty_state.vue';
import GraphGroup from '~/monitoring/components/graph_group.vue';
import GroupEmptyState from '~/monitoring/components/group_empty_state.vue';
import LinksSection from '~/monitoring/components/links_section.vue';
import { dashboardEmptyStates, metricStates } from '~/monitoring/constants';
import { createStore } from '~/monitoring/stores';
import * as types from '~/monitoring/stores/mutation_types';
import {
  metricsDashboardViewModel,
  metricsDashboardPanelCount,
  dashboardProps,
} from '../fixture_data';
import { dashboardGitResponse, storeVariables } from '../mock_data';
import {
  setupAllDashboards,
  setupStoreWithDashboard,
  setMetricResult,
  setupStoreWithData,
  setupStoreWithDataForPanelCount,
  setupStoreWithLinks,
} from '../store_utils';

jest.mock('~/flash');

describe('Dashboard', () => {
  let store;
  let wrapper;
  let mock;

  const createShallowWrapper = (props = {}, options = {}) => {
    wrapper = shallowMountExtended(Dashboard, {
      propsData: { ...dashboardProps, ...props },
      store,
      stubs: {
        DashboardHeader,
      },
      ...options,
    });
  };

  const createMountedWrapper = (props = {}, options = {}) => {
    wrapper = mountExtended(Dashboard, {
      propsData: { ...dashboardProps, ...props },
      store,
      stubs: {
        'graph-group': true,
        'dashboard-panel': true,
        'dashboard-header': DashboardHeader,
      },
      ...options,
    });
  };

  beforeEach(() => {
    store = createStore();
    mock = new MockAdapter(axios);
    jest.spyOn(store, 'dispatch').mockResolvedValue();
  });

  afterEach(() => {
    mock.restore();
    if (store.dispatch.mockReset) {
      store.dispatch.mockReset();
    }
    wrapper.destroy();
  });

  describe('request information to the server', () => {
    it('calls to set time range and fetch data', async () => {
      createShallowWrapper({ hasMetrics: true });

      await nextTick();
      expect(store.dispatch).toHaveBeenCalledWith(
        'monitoringDashboard/setTimeRange',
        expect.any(Object),
      );

      expect(store.dispatch).toHaveBeenCalledWith('monitoringDashboard/fetchData', undefined);
    });

    it('shows up a loading state', async () => {
      store.state.monitoringDashboard.emptyState = dashboardEmptyStates.LOADING;

      createShallowWrapper({ hasMetrics: true });

      await nextTick();
      expect(wrapper.find(EmptyState).exists()).toBe(true);
      expect(wrapper.find(EmptyState).props('selectedState')).toBe(dashboardEmptyStates.LOADING);
    });

    it('hides the group panels when showPanels is false', async () => {
      createMountedWrapper({ hasMetrics: true, showPanels: false });

      setupStoreWithData(store);

      await nextTick();
      expect(wrapper.vm.emptyState).toBeNull();
      expect(wrapper.findAll('.prometheus-panel')).toHaveLength(0);
    });

    it('fetches the metrics data with proper time window', async () => {
      createMountedWrapper({ hasMetrics: true });

      await nextTick();
      expect(store.dispatch).toHaveBeenCalledWith('monitoringDashboard/fetchData', undefined);
      expect(store.dispatch).toHaveBeenCalledWith(
        'monitoringDashboard/setTimeRange',
        expect.objectContaining({ duration: { seconds: 28800 } }),
      );
    });
  });

  describe('panel containers layout', () => {
    const findPanelLayoutWrapperAt = (index) => {
      return wrapper
        .find(GraphGroup)
        .findAll('[data-testid="dashboard-panel-layout-wrapper"]')
        .at(index);
    };

    beforeEach(async () => {
      createMountedWrapper({ hasMetrics: true });
      await nextTick();
    });

    describe('when the graph group has an even number of panels', () => {
      it('2 panels - all panel wrappers take half width of their parent', async () => {
        setupStoreWithDataForPanelCount(store, 2);

        await nextTick();
        expect(findPanelLayoutWrapperAt(0).classes('col-lg-6')).toBe(true);
        expect(findPanelLayoutWrapperAt(1).classes('col-lg-6')).toBe(true);
      });

      it('4 panels - all panel wrappers take half width of their parent', async () => {
        setupStoreWithDataForPanelCount(store, 4);

        await nextTick();
        expect(findPanelLayoutWrapperAt(0).classes('col-lg-6')).toBe(true);
        expect(findPanelLayoutWrapperAt(1).classes('col-lg-6')).toBe(true);
        expect(findPanelLayoutWrapperAt(2).classes('col-lg-6')).toBe(true);
        expect(findPanelLayoutWrapperAt(3).classes('col-lg-6')).toBe(true);
      });
    });

    describe('when the graph group has an odd number of panels', () => {
      it('1 panel - panel wrapper does not take half width of its parent', async () => {
        setupStoreWithDataForPanelCount(store, 1);

        await nextTick();
        expect(findPanelLayoutWrapperAt(0).classes('col-lg-6')).toBe(false);
      });

      it('3 panels - all panels but last take half width of their parents', async () => {
        setupStoreWithDataForPanelCount(store, 3);

        await nextTick();
        expect(findPanelLayoutWrapperAt(0).classes('col-lg-6')).toBe(true);
        expect(findPanelLayoutWrapperAt(1).classes('col-lg-6')).toBe(true);
        expect(findPanelLayoutWrapperAt(2).classes('col-lg-6')).toBe(false);
      });

      it('5 panels - all panels but last take half width of their parents', async () => {
        setupStoreWithDataForPanelCount(store, 5);

        await nextTick();
        expect(findPanelLayoutWrapperAt(0).classes('col-lg-6')).toBe(true);
        expect(findPanelLayoutWrapperAt(1).classes('col-lg-6')).toBe(true);
        expect(findPanelLayoutWrapperAt(2).classes('col-lg-6')).toBe(true);
        expect(findPanelLayoutWrapperAt(3).classes('col-lg-6')).toBe(true);
        expect(findPanelLayoutWrapperAt(4).classes('col-lg-6')).toBe(false);
      });
    });
  });

  describe('dashboard validation warning', () => {
    it('displays a warning if there are validation warnings', async () => {
      createMountedWrapper({ hasMetrics: true });

      store.commit(
        `monitoringDashboard/${types.RECEIVE_DASHBOARD_VALIDATION_WARNINGS_SUCCESS}`,
        true,
      );

      await nextTick();
      expect(createFlash).toHaveBeenCalled();
    });

    it('does not display a warning if there are no validation warnings', async () => {
      createMountedWrapper({ hasMetrics: true });

      store.commit(
        `monitoringDashboard/${types.RECEIVE_DASHBOARD_VALIDATION_WARNINGS_SUCCESS}`,
        false,
      );

      await nextTick();
      expect(createFlash).not.toHaveBeenCalled();
    });
  });

  describe('when the URL contains a reference to a panel', () => {
    const location = window.location.href;

    const setSearch = (searchParams) => {
      setWindowLocation(`?${objectToQuery(searchParams)}`);
    };

    afterEach(() => {
      setWindowLocation(location);
    });

    it('when the URL points to a panel it expands', async () => {
      const panelGroup = metricsDashboardViewModel.panelGroups[0];
      const panel = panelGroup.panels[0];

      setSearch({
        group: panelGroup.group,
        title: panel.title,
        y_label: panel.y_label,
      });

      createMountedWrapper({ hasMetrics: true });
      setupStoreWithData(store);

      await nextTick();
      expect(store.dispatch).toHaveBeenCalledWith('monitoringDashboard/setExpandedPanel', {
        group: panelGroup.group,
        panel: expect.objectContaining({
          title: panel.title,
          y_label: panel.y_label,
        }),
      });
    });

    it('when the URL does not link to any panel, no panel is expanded', async () => {
      setSearch();

      createMountedWrapper({ hasMetrics: true });
      setupStoreWithData(store);

      await nextTick();
      expect(store.dispatch).not.toHaveBeenCalledWith(
        'monitoringDashboard/setExpandedPanel',
        expect.anything(),
      );
    });

    it('when the URL points to an incorrect panel it shows an error', async () => {
      const panelGroup = metricsDashboardViewModel.panelGroups[0];
      const panel = panelGroup.panels[0];

      setSearch({
        group: panelGroup.group,
        title: 'incorrect',
        y_label: panel.y_label,
      });

      createMountedWrapper({ hasMetrics: true });
      setupStoreWithData(store);

      await nextTick();
      expect(createFlash).toHaveBeenCalled();
      expect(store.dispatch).not.toHaveBeenCalledWith(
        'monitoringDashboard/setExpandedPanel',
        expect.anything(),
      );
    });
  });

  describe('when the panel is expanded', () => {
    let group;
    let panel;

    const expandPanel = (mockGroup, mockPanel) => {
      store.commit(`monitoringDashboard/${types.SET_EXPANDED_PANEL}`, {
        group: mockGroup,
        panel: mockPanel,
      });
    };

    beforeEach(() => {
      setupStoreWithData(store);

      const { panelGroups } = store.state.monitoringDashboard.dashboard;
      group = panelGroups[0].group;
      [panel] = panelGroups[0].panels;

      jest.spyOn(window.history, 'pushState').mockImplementation();
    });

    afterEach(() => {
      window.history.pushState.mockRestore();
    });

    it('URL is updated with panel parameters', async () => {
      createMountedWrapper({ hasMetrics: true });
      expandPanel(group, panel);

      const expectedSearch = objectToQuery({
        group,
        title: panel.title,
        y_label: panel.y_label,
      });

      await nextTick();
      expect(window.history.pushState).toHaveBeenCalledTimes(1);
      expect(window.history.pushState).toHaveBeenCalledWith(
        expect.anything(), // state
        expect.any(String), // document title
        expect.stringContaining(`${expectedSearch}`),
      );
    });

    it('URL is updated with panel parameters and custom dashboard', async () => {
      const dashboard = 'dashboard.yml';

      store.commit(`monitoringDashboard/${types.SET_INITIAL_STATE}`, {
        currentDashboard: dashboard,
      });
      createMountedWrapper({ hasMetrics: true });
      expandPanel(group, panel);

      const expectedSearch = objectToQuery({
        dashboard,
        group,
        title: panel.title,
        y_label: panel.y_label,
      });

      await nextTick();
      expect(window.history.pushState).toHaveBeenCalledTimes(1);
      expect(window.history.pushState).toHaveBeenCalledWith(
        expect.anything(), // state
        expect.any(String), // document title
        expect.stringContaining(`${expectedSearch}`),
      );
    });

    it('URL is updated with no parameters', async () => {
      expandPanel(group, panel);
      createMountedWrapper({ hasMetrics: true });
      expandPanel(null, null);

      await nextTick();
      expect(window.history.pushState).toHaveBeenCalledTimes(1);
      expect(window.history.pushState).toHaveBeenCalledWith(
        expect.anything(), // state
        expect.any(String), // document title
        expect.not.stringMatching(/group|title|y_label/), // no panel params
      );
    });
  });

  describe('when all panels in the first group are loading', () => {
    const findGroupAt = (i) => wrapper.findAll(GraphGroup).at(i);

    beforeEach(async () => {
      setupStoreWithDashboard(store);

      const { panels } = store.state.monitoringDashboard.dashboard.panelGroups[0];
      panels.forEach(({ metrics }) => {
        store.commit(`monitoringDashboard/${types.REQUEST_METRIC_RESULT}`, {
          metricId: metrics[0].metricId,
        });
      });

      createShallowWrapper();

      await nextTick();
    });

    it('a loading icon appears in the first group', () => {
      expect(findGroupAt(0).props('isLoading')).toBe(true);
    });

    it('a loading icon does not appear in the second group', () => {
      expect(findGroupAt(1).props('isLoading')).toBe(false);
    });
  });

  describe('when all requests have been committed by the store', () => {
    beforeEach(async () => {
      store.commit(`monitoringDashboard/${types.SET_INITIAL_STATE}`, {
        currentEnvironmentName: 'production',
        currentDashboard: dashboardGitResponse[0].path,
        projectPath: TEST_HOST,
      });
      createMountedWrapper({ hasMetrics: true });
      setupStoreWithData(store);

      await nextTick();
    });

    it('it does not show loading icons in any group', async () => {
      setupStoreWithData(store);

      await nextTick();
      wrapper.findAll(GraphGroup).wrappers.forEach((groupWrapper) => {
        expect(groupWrapper.props('isLoading')).toBe(false);
      });
    });
  });

  describe('variables section', () => {
    beforeEach(async () => {
      createShallowWrapper({ hasMetrics: true });
      setupStoreWithData(store);
      store.state.monitoringDashboard.variables = storeVariables;
      await nextTick();
    });

    it('shows the variables section', () => {
      expect(wrapper.vm.shouldShowVariablesSection).toBe(true);
    });
  });

  describe('links section', () => {
    beforeEach(async () => {
      createShallowWrapper({ hasMetrics: true });
      setupStoreWithData(store);
      setupStoreWithLinks(store);
      await nextTick();
    });

    it('shows the links section', () => {
      expect(wrapper.vm.shouldShowLinksSection).toBe(true);
      expect(wrapper.findComponent(LinksSection).exists()).toBe(true);
    });
  });

  describe('single panel expands to "full screen" mode', () => {
    const findExpandedPanel = () => wrapper.find({ ref: 'expandedPanel' });

    describe('when the panel is not expanded', () => {
      beforeEach(async () => {
        createShallowWrapper({ hasMetrics: true });
        setupStoreWithData(store);
        await nextTick();
      });

      it('expanded panel is not visible', () => {
        expect(findExpandedPanel().isVisible()).toBe(false);
      });

      it('can set a panel as expanded', () => {
        const panel = wrapper.findAll(DashboardPanel).at(1);

        jest.spyOn(store, 'dispatch');

        panel.vm.$emit('expand');

        const groupData = metricsDashboardViewModel.panelGroups[0];

        expect(store.dispatch).toHaveBeenCalledWith('monitoringDashboard/setExpandedPanel', {
          group: groupData.group,
          panel: expect.objectContaining({
            id: groupData.panels[0].id,
          }),
        });
      });
    });

    describe('when the panel is expanded', () => {
      let group;
      let panel;

      const mockKeyup = (key) => window.dispatchEvent(new KeyboardEvent('keyup', { key }));

      const MockPanel = {
        template: `<div><slot name="top-left"/></div>`,
      };

      beforeEach(async () => {
        createShallowWrapper({ hasMetrics: true }, { stubs: { DashboardPanel: MockPanel } });
        setupStoreWithData(store);

        const { panelGroups } = store.state.monitoringDashboard.dashboard;

        group = panelGroups[0].group;
        [panel] = panelGroups[0].panels;

        store.commit(`monitoringDashboard/${types.SET_EXPANDED_PANEL}`, {
          group,
          panel,
        });

        jest.spyOn(store, 'dispatch');
        await nextTick();
      });

      it('displays a single panel and others are hidden', () => {
        const panels = wrapper.findAll(MockPanel);
        const visiblePanels = panels.filter((w) => w.isVisible());

        expect(findExpandedPanel().isVisible()).toBe(true);
        // v-show for hiding panels is more performant than v-if
        // check for panels to be hidden.
        expect(panels.length).toBe(metricsDashboardPanelCount + 1);
        expect(visiblePanels.length).toBe(1);
      });

      it('sets a link to the expanded panel', () => {
        const searchQuery =
          '?dashboard=config%2Fprometheus%2Fcommon_metrics.yml&group=System%20metrics%20(Kubernetes)&title=Memory%20Usage%20(Total)&y_label=Total%20Memory%20Used%20(GB)';

        expect(findExpandedPanel().attributes('clipboard-text')).toEqual(
          expect.stringContaining(searchQuery),
        );
      });

      it('restores full dashboard by clicking `back`', () => {
        wrapper.find({ ref: 'goBackBtn' }).vm.$emit('click');

        expect(store.dispatch).toHaveBeenCalledWith(
          'monitoringDashboard/clearExpandedPanel',
          undefined,
        );
      });

      it('restores dashboard from full screen by typing the Escape key', () => {
        mockKeyup(ESC_KEY);
        expect(store.dispatch).toHaveBeenCalledWith(
          `monitoringDashboard/clearExpandedPanel`,
          undefined,
        );
      });
    });
  });

  describe('when one of the metrics is missing', () => {
    beforeEach(async () => {
      createShallowWrapper({ hasMetrics: true });

      setupStoreWithDashboard(store);
      setMetricResult({ store, result: [], panel: 2 });
      await nextTick();
    });

    it('shows a group empty area', () => {
      const emptyGroup = wrapper.findAll({ ref: 'empty-group' });

      expect(emptyGroup).toHaveLength(1);
      expect(emptyGroup.is(GroupEmptyState)).toBe(true);
    });

    it('group empty area displays a NO_DATA state', () => {
      expect(wrapper.findAll({ ref: 'empty-group' }).at(0).props('selectedState')).toEqual(
        metricStates.NO_DATA,
      );
    });
  });

  describe('drag and drop function', () => {
    const findDraggables = () => wrapper.findAll(VueDraggable);
    const findEnabledDraggables = () => findDraggables().filter((f) => !f.attributes('disabled'));
    const findDraggablePanels = () => wrapper.findAll('.js-draggable-panel');
    const findRearrangeButton = () => wrapper.find('.js-rearrange-button');

    const setup = async () => {
      // call original dispatch
      store.dispatch.mockRestore();

      createShallowWrapper({ hasMetrics: true });
      setupStoreWithData(store);
      await nextTick();
    };

    it('wraps vuedraggable', async () => {
      await setup();

      expect(findDraggablePanels().exists()).toBe(true);
      expect(findDraggablePanels().length).toEqual(metricsDashboardPanelCount);
    });

    it('is disabled by default', async () => {
      await setup();

      expect(findRearrangeButton().exists()).toBe(false);
      expect(findEnabledDraggables().length).toBe(0);
    });

    describe('when rearrange is enabled', () => {
      beforeEach(async () => {
        // call original dispatch
        store.dispatch.mockRestore();

        createShallowWrapper({ hasMetrics: true, rearrangePanelsAvailable: true });
        setupStoreWithData(store);

        await nextTick();
      });

      it('displays rearrange button', () => {
        expect(findRearrangeButton().exists()).toBe(true);
      });

      describe('when rearrange button is clicked', () => {
        const findFirstDraggableRemoveButton = () =>
          findDraggablePanels().at(0).find('.js-draggable-remove');

        it('it enables draggables', async () => {
          findRearrangeButton().vm.$emit('click');
          await nextTick();

          expect(findRearrangeButton().attributes('pressed')).toBeTruthy();
          expect(findEnabledDraggables().wrappers).toEqual(findDraggables().wrappers);
        });

        it('metrics can be swapped', async () => {
          findRearrangeButton().vm.$emit('click');
          await nextTick();

          const firstDraggable = findDraggables().at(0);
          const mockMetrics = [...metricsDashboardViewModel.panelGroups[0].panels];

          const firstTitle = mockMetrics[0].title;
          const secondTitle = mockMetrics[1].title;

          // swap two elements and `input` them
          [mockMetrics[0], mockMetrics[1]] = [mockMetrics[1], mockMetrics[0]];
          firstDraggable.vm.$emit('input', mockMetrics);

          await nextTick();

          const { panels } = wrapper.vm.dashboard.panelGroups[0];

          expect(panels[1].title).toEqual(firstTitle);
          expect(panels[0].title).toEqual(secondTitle);
        });

        it('shows a remove button, which removes a panel', async () => {
          findRearrangeButton().vm.$emit('click');
          await nextTick();

          expect(findFirstDraggableRemoveButton().find('a').exists()).toBe(true);

          expect(findDraggablePanels().length).toEqual(metricsDashboardPanelCount);
          await findFirstDraggableRemoveButton().trigger('click');

          expect(findDraggablePanels().length).toEqual(metricsDashboardPanelCount - 1);
        });

        it('it disables draggables when clicked again', async () => {
          findRearrangeButton().vm.$emit('click');
          await nextTick();

          findRearrangeButton().vm.$emit('click');
          await nextTick();
          expect(findRearrangeButton().attributes('pressed')).toBeFalsy();
          expect(findEnabledDraggables().length).toBe(0);
        });
      });
    });
  });

  describe('cluster health', () => {
    beforeEach(async () => {
      createShallowWrapper({ hasMetrics: true, showHeader: false });

      // all_dashboards is not defined in health dashboards
      store.commit(`monitoringDashboard/${types.SET_ALL_DASHBOARDS}`, undefined);
      await nextTick();
    });

    it('hides dashboard header by default', () => {
      expect(wrapper.find({ ref: 'prometheusGraphsHeader' }).exists()).toEqual(false);
    });

    it('renders correctly', () => {
      expect(wrapper.html()).not.toBe('');
    });
  });

  describe('document title', () => {
    const originalTitle = 'Original Title';
    const overviewDashboardName = dashboardGitResponse[0].display_name;

    beforeEach(() => {
      document.title = originalTitle;
      createShallowWrapper({ hasMetrics: true });
    });

    afterAll(() => {
      document.title = '';
    });

    it('is prepended with the overview dashboard name by default', async () => {
      setupAllDashboards(store);

      await nextTick();
      expect(document.title.startsWith(`${overviewDashboardName} · `)).toBe(true);
    });

    it('is prepended with dashboard name if path is known', async () => {
      const dashboard = dashboardGitResponse[1];
      const currentDashboard = dashboard.path;

      setupAllDashboards(store, currentDashboard);

      await nextTick();
      expect(document.title.startsWith(`${dashboard.display_name} · `)).toBe(true);
    });

    it('is prepended with the overview dashboard name if path is not known', async () => {
      setupAllDashboards(store, 'unknown/path');

      await nextTick();
      expect(document.title.startsWith(`${overviewDashboardName} · `)).toBe(true);
    });

    it('is not modified when dashboard name is not provided', async () => {
      const dashboard = { ...dashboardGitResponse[1], display_name: null };
      const currentDashboard = dashboard.path;

      store.commit(`monitoringDashboard/${types.SET_ALL_DASHBOARDS}`, [dashboard]);

      store.commit(`monitoringDashboard/${types.SET_INITIAL_STATE}`, {
        currentDashboard,
      });

      await nextTick();
      expect(document.title).toBe(originalTitle);
    });
  });

  describe('Clipboard text in panels', () => {
    const currentDashboard = dashboardGitResponse[1].path;
    const panelIndex = 1; // skip expanded panel

    const getClipboardTextFirstPanel = () =>
      wrapper.findAll(DashboardPanel).at(panelIndex).props('clipboardText');

    beforeEach(async () => {
      setupStoreWithData(store);
      store.commit(`monitoringDashboard/${types.SET_INITIAL_STATE}`, {
        currentDashboard,
      });
      createShallowWrapper({ hasMetrics: true });
      await nextTick();
    });

    it('contains a link to the dashboard', () => {
      const dashboardParam = `dashboard=${encodeURIComponent(currentDashboard)}`;

      expect(getClipboardTextFirstPanel()).toContain(dashboardParam);
      expect(getClipboardTextFirstPanel()).toContain(`group=`);
      expect(getClipboardTextFirstPanel()).toContain(`title=`);
      expect(getClipboardTextFirstPanel()).toContain(`y_label=`);
    });
  });

  describe('keyboard shortcuts', () => {
    const currentDashboard = dashboardGitResponse[1].path;
    const panelRef = 'dashboard-panel-response-metrics-aws-elb-4-1'; // skip expanded panel

    // While the recommendation in the documentation is to test
    // with a data-testid attribute, I want to make sure that
    // the dashboard panels have a ref attribute set.
    const getDashboardPanel = () => wrapper.find({ ref: panelRef });

    beforeEach(async () => {
      setupStoreWithData(store);
      store.commit(`monitoringDashboard/${types.SET_INITIAL_STATE}`, {
        currentDashboard,
      });
      createShallowWrapper({ hasMetrics: true });

      // setData usage is discouraged. See https://gitlab.com/groups/gitlab-org/-/epics/7330 for details
      // eslint-disable-next-line no-restricted-syntax
      wrapper.setData({ hoveredPanel: panelRef });
      await nextTick();
    });

    it('contains a ref attribute inside a DashboardPanel component', () => {
      const dashboardPanel = getDashboardPanel();

      expect(dashboardPanel.exists()).toBe(true);
    });
  });
});
