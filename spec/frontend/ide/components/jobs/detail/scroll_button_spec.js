import { shallowMount } from '@vue/test-utils';
import Icon from '~/vue_shared/components/icon.vue';
import ScrollButton from '~/ide/components/jobs/detail/scroll_button.vue';

describe('IDE job log scroll button', () => {
  let wrapper;

  const createComponent = props => {
    wrapper = shallowMount(ScrollButton, {
      propsData: {
        direction: 'up',
        disabled: false,
        ...props,
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  describe.each`
    direction | icon             | title
    ${'up'}   | ${'scroll_up'}   | ${'Scroll to top'}
    ${'down'} | ${'scroll_down'} | ${'Scroll to bottom'}
  `('for $direction direction', ({ direction, icon, title }) => {
    beforeEach(() => createComponent({ direction }));

    it('returns proper icon name', () => {
      expect(wrapper.find(Icon).props('name')).toBe(icon);
    });

    it('returns proper title', () => {
      expect(wrapper.attributes('data-original-title')).toBe(title);
    });
  });

  it('emits click event on click', () => {
    createComponent();

    wrapper.find('button').trigger('click');
    expect(wrapper.emitted().click).toBeDefined();
  });

  it('disables button when disabled is true', () => {
    createComponent({ disabled: true });

    expect(wrapper.find('button').attributes('disabled')).toBe('disabled');
  });
});
