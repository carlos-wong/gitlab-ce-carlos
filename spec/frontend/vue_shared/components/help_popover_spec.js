import { GlButton, GlPopover } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import HelpPopover from '~/vue_shared/components/help_popover.vue';

describe('HelpPopover', () => {
  let wrapper;
  const title = 'popover <strong>title</strong>';
  const content = 'popover <b>content</b>';

  const findQuestionButton = () => wrapper.find(GlButton);
  const findPopover = () => wrapper.find(GlPopover);

  const createComponent = ({ props, ...opts } = {}) => {
    wrapper = mount(HelpPopover, {
      propsData: {
        options: {
          title,
          content,
        },
        ...props,
      },
      ...opts,
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  describe('with title and content', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders a link button with an icon question', () => {
      expect(findQuestionButton().props()).toMatchObject({
        icon: 'question-o',
        variant: 'link',
      });
    });

    it('renders popover that uses the question button as target', () => {
      expect(findPopover().props().target()).toBe(findQuestionButton().vm.$el);
    });

    it('shows title and content', () => {
      expect(findPopover().html()).toContain(title);
      expect(findPopover().html()).toContain(content);
    });

    it('allows rendering title with HTML tags', () => {
      expect(findPopover().find('strong').exists()).toBe(true);
    });

    it('allows rendering content with HTML tags', () => {
      expect(findPopover().find('b').exists()).toBe(true);
    });
  });

  describe('without title', () => {
    beforeEach(() => {
      createComponent({
        props: {
          options: {
            title: null,
            content,
          },
        },
      });
    });

    it('does not show title', () => {
      expect(findPopover().html()).not.toContain(title);
    });

    it('shows content', () => {
      expect(findPopover().html()).toContain(content);
    });
  });

  describe('with other options', () => {
    const placement = 'bottom';

    beforeEach(() => {
      createComponent({
        props: {
          options: {
            placement,
          },
        },
      });
    });

    it('options bind to the popover', () => {
      expect(findPopover().props().placement).toBe(placement);
    });
  });

  describe('with custom slots', () => {
    const titleSlot = '<h1>title</h1>';
    const defaultSlot = '<strong>content</strong>';

    beforeEach(() => {
      createComponent({
        slots: {
          title: titleSlot,
          default: defaultSlot,
        },
      });
    });

    it('shows title slot', () => {
      expect(findPopover().html()).toContain(titleSlot);
    });

    it('shows default content slot', () => {
      expect(findPopover().html()).toContain(defaultSlot);
    });

    it('overrides title and content from options', () => {
      expect(findPopover().html()).not.toContain(title);
      expect(findPopover().html()).toContain(content);
    });
  });
});
