import { shallowMount } from '@vue/test-utils';
import AxiosMockAdapter from 'axios-mock-adapter';
import { setTestTimeout } from 'helpers/timeout';
import axios from '~/lib/utils/axios_utils';
import PanelType from '~/monitoring/components/panel_type.vue';
import EmptyChart from '~/monitoring/components/charts/empty_chart.vue';
import TimeSeriesChart from '~/monitoring/components/charts/time_series.vue';
import AnomalyChart from '~/monitoring/components/charts/anomaly.vue';
import { graphDataPrometheusQueryRange } from '../../javascripts/monitoring/mock_data';
import { anomalyMockGraphData } from '../../frontend/monitoring/mock_data';
import { createStore } from '~/monitoring/stores';

global.IS_EE = true;
global.URL.createObjectURL = jest.fn();

describe('Panel Type component', () => {
  let axiosMock;
  let store;
  let panelType;
  const dashboardWidth = 100;
  const exampleText = 'example_text';

  const createWrapper = props =>
    shallowMount(PanelType, {
      propsData: {
        ...props,
      },
      store,
    });

  beforeEach(() => {
    setTestTimeout(1000);
    axiosMock = new AxiosMockAdapter(axios);
  });

  afterEach(() => {
    axiosMock.reset();
  });

  describe('When no graphData is available', () => {
    let glEmptyChart;
    // Deep clone object before modifying
    const graphDataNoResult = JSON.parse(JSON.stringify(graphDataPrometheusQueryRange));
    graphDataNoResult.metrics[0].result = [];

    beforeEach(() => {
      panelType = createWrapper({
        dashboardWidth,
        graphData: graphDataNoResult,
      });
    });

    afterEach(() => {
      panelType.destroy();
    });

    describe('Empty Chart component', () => {
      beforeEach(() => {
        glEmptyChart = panelType.find(EmptyChart);
      });

      it('is a Vue instance', () => {
        expect(glEmptyChart.isVueInstance()).toBe(true);
      });

      it('it receives a graph title', () => {
        const props = glEmptyChart.props();

        expect(props.graphTitle).toBe(panelType.vm.graphData.title);
      });
    });
  });

  describe('when graph data is available', () => {
    beforeEach(() => {
      store = createStore();
      panelType = createWrapper({
        dashboardWidth,
        graphData: graphDataPrometheusQueryRange,
      });
    });

    afterEach(() => {
      panelType.destroy();
    });

    it('sets no clipboard copy link on dropdown by default', () => {
      const link = () => panelType.find('.js-chart-link');
      expect(link().exists()).toBe(false);
    });

    describe('Time Series Chart panel type', () => {
      it('is rendered', () => {
        expect(panelType.find(TimeSeriesChart).isVueInstance()).toBe(true);
        expect(panelType.find(TimeSeriesChart).exists()).toBe(true);
      });

      it('includes a default group id', () => {
        expect(panelType.vm.groupId).toBe('panel-type-chart');
      });
    });

    describe('Anomaly Chart panel type', () => {
      beforeEach(done => {
        panelType.setProps({
          graphData: anomalyMockGraphData,
        });
        panelType.vm.$nextTick(done);
      });

      it('is rendered with an anomaly chart', () => {
        expect(panelType.find(AnomalyChart).isVueInstance()).toBe(true);
        expect(panelType.find(AnomalyChart).exists()).toBe(true);
      });
    });
  });

  describe('when cliboard data is available', () => {
    const clipboardText = 'A value to copy.';

    beforeEach(() => {
      store = createStore();
      panelType = createWrapper({
        clipboardText,
        dashboardWidth,
        graphData: graphDataPrometheusQueryRange,
      });
    });

    afterEach(() => {
      panelType.destroy();
    });

    it('sets clipboard text on the dropdown', () => {
      const link = () => panelType.find('.js-chart-link');

      expect(link().exists()).toBe(true);
      expect(link().element.dataset.clipboardText).toBe(clipboardText);
    });
  });

  describe('when downloading metrics data as CSV', () => {
    beforeEach(done => {
      graphDataPrometheusQueryRange.y_label = 'metric';
      store = createStore();
      panelType = shallowMount(PanelType, {
        propsData: {
          clipboardText: exampleText,
          dashboardWidth,
          graphData: graphDataPrometheusQueryRange,
        },
        store,
      });
      panelType.vm.$nextTick(done);
    });

    afterEach(() => {
      panelType.destroy();
    });

    describe('csvText', () => {
      it('converts metrics data from json to csv', () => {
        const header = `timestamp,${graphDataPrometheusQueryRange.y_label}`;
        const data = graphDataPrometheusQueryRange.metrics[0].result[0].values;
        const firstRow = `${data[0][0]},${data[0][1]}`;
        const secondRow = `${data[1][0]},${data[1][1]}`;

        expect(panelType.vm.csvText).toBe(`${header}\r\n${firstRow}\r\n${secondRow}\r\n`);
      });
    });

    describe('downloadCsv', () => {
      it('produces a link with a Blob', () => {
        expect(global.URL.createObjectURL).toHaveBeenLastCalledWith(expect.any(Blob));
        expect(global.URL.createObjectURL).toHaveBeenLastCalledWith(
          expect.objectContaining({
            size: panelType.vm.csvText.length,
            type: 'text/plain',
          }),
        );
      });
    });
  });
});
