import { shallowMount } from '@vue/test-utils';
import router from '~/ide/ide_router';
import Item from '~/ide/components/branches/item.vue';
import Icon from '~/vue_shared/components/icon.vue';
import Timeago from '~/vue_shared/components/time_ago_tooltip.vue';
import { projectData } from '../../mock_data';

const TEST_BRANCH = {
  name: 'master',
  committedDate: '2018-01-05T05:50Z',
};
const TEST_PROJECT_ID = projectData.name_with_namespace;

describe('IDE branch item', () => {
  let wrapper;

  function createComponent(props = {}) {
    wrapper = shallowMount(Item, {
      propsData: {
        item: { ...TEST_BRANCH },
        projectId: TEST_PROJECT_ID,
        isActive: false,
        ...props,
      },
    });
  }

  afterEach(() => {
    wrapper.destroy();
  });

  describe('if not active', () => {
    beforeEach(() => {
      createComponent();
    });
    it('renders branch name and timeago', () => {
      expect(wrapper.text()).toContain(TEST_BRANCH.name);
      expect(wrapper.find(Timeago).props('time')).toBe(TEST_BRANCH.committedDate);
      expect(wrapper.find(Icon).exists()).toBe(false);
    });

    it('renders link to branch', () => {
      const expectedHref = router.resolve(`/project/${TEST_PROJECT_ID}/edit/${TEST_BRANCH.name}`)
        .href;

      expect(wrapper.text()).toMatch('a');
      expect(wrapper.attributes('href')).toBe(expectedHref);
    });
  });

  it('renders icon if is not active', () => {
    createComponent({ isActive: true });

    expect(wrapper.find(Icon).exists()).toBe(true);
  });
});
