import { GlAlert, GlButton, GlButtonGroup, GlLoadingIcon } from '@gitlab/ui';
import { mount, shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mockTracking, unmockTracking } from 'helpers/tracking_helper';
import { LAYER_VIEW, STAGE_VIEW } from '~/pipelines/components/graph/constants';
import GraphViewSelector from '~/pipelines/components/graph/graph_view_selector.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import getPerformanceInsights from '~/pipelines/graphql/queries/get_performance_insights.query.graphql';
import { mockPerformanceInsightsResponse } from './mock_data';

Vue.use(VueApollo);

describe('the graph view selector component', () => {
  let wrapper;
  let trackingSpy;

  const findDependenciesToggle = () => wrapper.find('[data-testid="show-links-toggle"]');
  const findViewTypeSelector = () => wrapper.findComponent(GlButtonGroup);
  const findStageViewButton = () => findViewTypeSelector().findAllComponents(GlButton).at(0);
  const findLayerViewButton = () => findViewTypeSelector().findAllComponents(GlButton).at(1);
  const findSwitcherLoader = () => wrapper.find('[data-testid="switcher-loading-state"]');
  const findToggleLoader = () => findDependenciesToggle().find(GlLoadingIcon);
  const findHoverTip = () => wrapper.findComponent(GlAlert);
  const findPipelineInsightsBtn = () => wrapper.find('[data-testid="pipeline-insights-btn"]');

  const defaultProps = {
    showLinks: false,
    tipPreviouslyDismissed: false,
    type: STAGE_VIEW,
    isPipelineComplete: true,
  };

  const defaultData = {
    hoverTipDismissed: false,
    isToggleLoading: false,
    isSwitcherLoading: false,
    showLinksActive: false,
  };

  const getPerformanceInsightsHandler = jest
    .fn()
    .mockResolvedValue(mockPerformanceInsightsResponse);

  const requestHandlers = [[getPerformanceInsights, getPerformanceInsightsHandler]];

  const apolloProvider = createMockApollo(requestHandlers);

  const createComponent = ({ data = {}, mountFn = shallowMount, props = {} } = {}) => {
    wrapper = mountFn(GraphViewSelector, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      data() {
        return {
          ...defaultData,
          ...data,
        };
      },
      apolloProvider,
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  describe('when showing stage view', () => {
    beforeEach(() => {
      createComponent({ mountFn: mount });
    });

    it('shows the Stage view button as selected', () => {
      expect(findStageViewButton().classes('selected')).toBe(true);
    });

    it('shows the Job dependencies view button not selected', () => {
      expect(findLayerViewButton().exists()).toBe(true);
      expect(findLayerViewButton().classes('selected')).toBe(false);
    });

    it('does not show the Job dependencies (links) toggle', () => {
      expect(findDependenciesToggle().exists()).toBe(false);
    });
  });

  describe('when showing Job dependencies view', () => {
    beforeEach(() => {
      createComponent({
        mountFn: mount,
        props: {
          type: LAYER_VIEW,
        },
      });
    });

    it('shows the Job dependencies view as selected', () => {
      expect(findLayerViewButton().classes('selected')).toBe(true);
    });

    it('shows the Stage button as not selected', () => {
      expect(findStageViewButton().exists()).toBe(true);
      expect(findStageViewButton().classes('selected')).toBe(false);
    });

    it('shows the Job dependencies (links) toggle', () => {
      expect(findDependenciesToggle().exists()).toBe(true);
    });
  });

  describe('events', () => {
    beforeEach(() => {
      createComponent({
        mountFn: mount,
        props: {
          type: LAYER_VIEW,
        },
      });
    });

    it('shows loading state and emits updateViewType when view type toggled', async () => {
      expect(wrapper.emitted().updateViewType).toBeUndefined();
      expect(findSwitcherLoader().exists()).toBe(false);

      await findStageViewButton().trigger('click');
      /*
        Loading happens before the event is emitted or timers are run.
        Then we run the timer because the event is emitted in setInterval
        which is what gives the loader a chace to show up.
      */
      expect(findSwitcherLoader().exists()).toBe(true);
      jest.runOnlyPendingTimers();

      expect(wrapper.emitted().updateViewType).toHaveLength(1);
      expect(wrapper.emitted().updateViewType).toEqual([[STAGE_VIEW]]);
    });

    it('shows loading state and emits updateShowLinks when show links toggle is clicked', async () => {
      expect(wrapper.emitted().updateShowLinksState).toBeUndefined();
      expect(findToggleLoader().exists()).toBe(false);

      await findDependenciesToggle().vm.$emit('change', true);
      /*
        Loading happens before the event is emitted or timers are run.
        Then we run the timer because the event is emitted in setInterval
        which is what gives the loader a chace to show up.
      */
      expect(findToggleLoader().exists()).toBe(true);
      jest.runOnlyPendingTimers();

      expect(wrapper.emitted().updateShowLinksState).toHaveLength(1);
      expect(wrapper.emitted().updateShowLinksState).toEqual([[true]]);
    });

    it('does not emit an event if the click occurs on the currently selected view button', async () => {
      expect(wrapper.emitted().updateShowLinksState).toBeUndefined();

      await findLayerViewButton().trigger('click');

      expect(wrapper.emitted().updateShowLinksState).toBeUndefined();
    });
  });

  describe('hover tip callout', () => {
    describe('when links are live and it has not been previously dismissed', () => {
      beforeEach(() => {
        createComponent({
          props: {
            showLinks: true,
          },
          data: {
            showLinksActive: true,
          },
          mountFn: mount,
        });
      });

      it('is displayed', () => {
        expect(findHoverTip().exists()).toBe(true);
        expect(findHoverTip().text()).toBe(wrapper.vm.$options.i18n.hoverTipText);
      });

      it('emits dismissHoverTip event when the tip is dismissed', async () => {
        expect(wrapper.emitted().dismissHoverTip).toBeUndefined();
        await findHoverTip().find('button').trigger('click');
        expect(wrapper.emitted().dismissHoverTip).toHaveLength(1);
      });
    });

    describe('when links are live and it has been previously dismissed', () => {
      beforeEach(() => {
        createComponent({
          props: {
            showLinks: true,
            tipPreviouslyDismissed: true,
          },
          data: {
            showLinksActive: true,
          },
        });
      });

      it('is not displayed', () => {
        expect(findHoverTip().exists()).toBe(false);
      });
    });

    describe('when links are not live', () => {
      beforeEach(() => {
        createComponent({
          props: {
            showLinks: true,
          },
          data: {
            showLinksActive: false,
          },
        });
      });

      it('is not displayed', () => {
        expect(findHoverTip().exists()).toBe(false);
      });
    });

    describe('pipeline insights', () => {
      it.each`
        isPipelineComplete | shouldShow
        ${true}            | ${true}
        ${false}           | ${false}
      `(
        'button should display $shouldShow if isPipelineComplete is $isPipelineComplete ',
        ({ isPipelineComplete, shouldShow }) => {
          createComponent({
            props: {
              isPipelineComplete,
            },
          });

          expect(findPipelineInsightsBtn().exists()).toBe(shouldShow);
        },
      );
    });

    describe('tracking', () => {
      beforeEach(() => {
        createComponent();

        trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      });

      afterEach(() => {
        unmockTracking();
      });

      it('tracks performance insights button click', () => {
        findPipelineInsightsBtn().vm.$emit('click');

        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_insights_button', {
          label: 'performance_insights',
        });
      });
    });
  });
});
