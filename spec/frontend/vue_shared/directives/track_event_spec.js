import Vue from 'vue';
import { createLocalVue, shallowMount } from '@vue/test-utils';
import Tracking from '~/tracking';
import TrackEvent from '~/vue_shared/directives/track_event';

jest.mock('~/tracking');

const Component = Vue.component('dummy-element', {
  directives: {
    TrackEvent,
  },
  data() {
    return {
      trackingOptions: null,
    };
  },
  template: '<button id="trackable" v-track-event="trackingOptions"></button>',
});

const localVue = createLocalVue();
let wrapper;
let button;

describe('Error Tracking directive', () => {
  beforeEach(() => {
    wrapper = shallowMount(localVue.extend(Component), {
      localVue,
    });
    button = wrapper.find('#trackable');
  });

  it('should not track the event if required arguments are not provided', () => {
    button.trigger('click');
    expect(Tracking.event).not.toHaveBeenCalled();
  });

  it('should track event on click if tracking info provided', () => {
    const trackingOptions = {
      category: 'Tracking',
      action: 'click_trackable_btn',
      label: 'Trackable Info',
    };

    wrapper.setData({ trackingOptions });
    const { category, action, label, property, value } = trackingOptions;
    button.trigger('click');
    expect(Tracking.event).toHaveBeenCalledWith(category, action, { label, property, value });
  });
});
