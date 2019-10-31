import { createLocalVue, shallowMount } from '@vue/test-utils';
import GlFeatureFlags from '~/vue_shared/gl_feature_flags_plugin';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';

const localVue = createLocalVue();

describe('GitLab Feature Flags Plugin', () => {
  beforeEach(() => {
    window.gon = {
      features: {
        aFeature: true,
        bFeature: false,
      },
    };

    localVue.use(GlFeatureFlags);
  });

  it('should provide glFeatures to components', () => {
    const component = {
      template: `<span></span>`,
      inject: ['glFeatures'],
    };
    const wrapper = shallowMount(component, { localVue });
    expect(wrapper.vm.glFeatures).toEqual({
      aFeature: true,
      bFeature: false,
    });
  });

  it('should integrate with the glFeatureMixin', () => {
    const component = {
      template: `<span></span>`,
      mixins: [glFeatureFlagsMixin()],
    };
    const wrapper = shallowMount(component, { localVue });
    expect(wrapper.vm.glFeatures).toEqual({
      aFeature: true,
      bFeature: false,
    });
  });
});
