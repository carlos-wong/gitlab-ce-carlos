import { shallowMount } from '@vue/test-utils';
import Component from '~/projects/pipelines/charts/components/statistics_list.vue';
import { counts } from '../mock_data';

describe('StatisticsList', () => {
  let wrapper;

  beforeEach(() => {
    wrapper = shallowMount(Component, {
      propsData: {
        counts,
      },
    });
  });

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
  });

  it('matches the snapshot', () => {
    expect(wrapper.element).toMatchSnapshot();
  });
});
