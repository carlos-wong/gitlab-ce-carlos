import { shallowMount } from '@vue/test-utils';
import PrometheusHeader from '~/monitoring/components/shared/prometheus_header.vue';

describe('Prometheus Header component', () => {
  let prometheusHeader;

  beforeEach(() => {
    prometheusHeader = shallowMount(PrometheusHeader, {
      propsData: {
        graphTitle: 'graph header',
      },
    });
  });

  afterEach(() => {
    prometheusHeader.destroy();
  });

  describe('Prometheus header component', () => {
    it('should show a title', () => {
      const title = prometheusHeader.vm.$el.querySelector('.js-graph-title').textContent;

      expect(title).toBe('graph header');
    });
  });
});
