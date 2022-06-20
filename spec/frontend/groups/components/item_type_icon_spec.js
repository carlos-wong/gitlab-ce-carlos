import { GlIcon } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import ItemTypeIcon from '~/groups/components/item_type_icon.vue';
import { ITEM_TYPE } from '../mock_data';

describe('ItemTypeIcon', () => {
  let wrapper;

  const defaultProps = {
    itemType: ITEM_TYPE.GROUP,
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMount(ItemTypeIcon, {
      propsData: { ...defaultProps, ...props },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
      wrapper = null;
    }
  });

  const findGlIcon = () => wrapper.find(GlIcon);

  describe('template', () => {
    it('renders component template correctly', () => {
      createComponent();

      expect(wrapper.classes()).toContain('item-type-icon');
    });

    it.each`
      type                 | icon
      ${ITEM_TYPE.GROUP}   | ${'subgroup'}
      ${ITEM_TYPE.PROJECT} | ${'project'}
    `('shows "$icon" icon when `itemType` is "$type"', ({ type, icon }) => {
      createComponent({
        itemType: type,
      });
      expect(findGlIcon().props('name')).toBe(icon);
    });
  });
});
