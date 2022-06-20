import { GlAvatar, GlAvatarLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import pipelineTriggerer from '~/pipelines/components/pipelines_list/pipeline_triggerer.vue';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';

describe('Pipelines Triggerer', () => {
  let wrapper;

  const mockData = {
    pipeline: {
      user: {
        name: 'foo',
        avatar_url: '/avatar',
        path: '/path',
      },
    },
  };

  const createComponent = (props) => {
    wrapper = shallowMountExtended(pipelineTriggerer, {
      propsData: {
        ...props,
      },
      directives: {
        GlTooltip: createMockDirective(),
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  const findAvatarLink = () => wrapper.findComponent(GlAvatarLink);
  const findAvatar = () => wrapper.findComponent(GlAvatar);
  const findTriggerer = () => wrapper.findByText('API');

  describe('when user was a triggerer', () => {
    beforeEach(() => {
      createComponent(mockData);
    });

    it('should render pipeline triggerer table cell', () => {
      expect(wrapper.find('[data-testid="pipeline-triggerer"]').exists()).toBe(true);
    });

    it('should render only user avatar', () => {
      expect(findAvatarLink().exists()).toBe(true);
      expect(findTriggerer().exists()).toBe(false);
    });

    it('should set correct props on avatar link component', () => {
      expect(findAvatarLink().attributes()).toMatchObject({
        title: mockData.pipeline.user.name,
        href: mockData.pipeline.user.path,
      });
    });

    it('should add tooltip to avatar link', () => {
      const tooltip = getBinding(findAvatarLink().element, 'gl-tooltip');

      expect(tooltip).toBeDefined();
    });

    it('should set correct props on avatar component', () => {
      expect(findAvatar().attributes().src).toBe(mockData.pipeline.user.avatar_url);
    });
  });

  describe('when API was a triggerer', () => {
    beforeEach(() => {
      createComponent({ pipeline: {} });
    });

    it('should render label only', () => {
      expect(findAvatarLink().exists()).toBe(false);
      expect(findTriggerer().exists()).toBe(true);
    });
  });
});
