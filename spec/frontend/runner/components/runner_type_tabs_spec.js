import { GlTab } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import RunnerTypeTabs from '~/runner/components/runner_type_tabs.vue';
import RunnerCount from '~/runner/components/stat/runner_count.vue';
import { INSTANCE_TYPE, GROUP_TYPE, PROJECT_TYPE } from '~/runner/constants';

const mockSearch = { runnerType: null, filters: [], pagination: { page: 1 }, sort: 'CREATED_DESC' };

const mockCount = (type, multiplier = 1) => {
  let count;
  switch (type) {
    case INSTANCE_TYPE:
      count = 3;
      break;
    case GROUP_TYPE:
      count = 2;
      break;
    case PROJECT_TYPE:
      count = 1;
      break;
    default:
      count = 6;
      break;
  }
  return count * multiplier;
};

describe('RunnerTypeTabs', () => {
  let wrapper;

  const findTabs = () => wrapper.findAll(GlTab);
  const findActiveTab = () =>
    findTabs()
      .filter((tab) => tab.attributes('active') === 'true')
      .at(0);
  const getTabsTitles = () => findTabs().wrappers.map((tab) => tab.text().replace(/\s+/g, ' '));

  const createComponent = ({ props, stubs, ...options } = {}) => {
    wrapper = shallowMount(RunnerTypeTabs, {
      propsData: {
        value: mockSearch,
        countScope: INSTANCE_TYPE,
        countVariables: {},
        ...props,
      },
      stubs: {
        GlTab,
        ...stubs,
      },
      ...options,
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  it('Renders all options to filter runners by default', () => {
    createComponent();

    expect(getTabsTitles()).toEqual(['All', 'Instance', 'Group', 'Project']);
  });

  it('Shows count when receiving a number', () => {
    createComponent({
      stubs: {
        RunnerCount: {
          props: ['variables'],
          render() {
            return this.$scopedSlots.default({
              count: mockCount(this.variables.type),
            });
          },
        },
      },
    });

    expect(getTabsTitles()).toEqual([`All 6`, `Instance 3`, `Group 2`, `Project 1`]);
  });

  it('Shows formatted count when receiving a large number', () => {
    createComponent({
      stubs: {
        RunnerCount: {
          props: ['variables'],
          render() {
            return this.$scopedSlots.default({
              count: mockCount(this.variables.type, 1000),
            });
          },
        },
      },
    });

    expect(getTabsTitles()).toEqual([
      `All 6,000`,
      `Instance 3,000`,
      `Group 2,000`,
      `Project 1,000`,
    ]);
  });

  it('Renders a count next to each tab', () => {
    const mockVariables = {
      paused: true,
      status: 'ONLINE',
    };

    createComponent({
      props: {
        countVariables: mockVariables,
      },
    });

    findTabs().wrappers.forEach((tab) => {
      expect(tab.find(RunnerCount).props()).toEqual({
        scope: INSTANCE_TYPE,
        skip: false,
        variables: expect.objectContaining(mockVariables),
      });
    });
  });

  it('Renders fewer options to filter runners', () => {
    createComponent({
      props: {
        runnerTypes: [GROUP_TYPE, PROJECT_TYPE],
      },
    });

    expect(getTabsTitles()).toEqual(['All', 'Group', 'Project']);
  });

  it('"All" is selected by default', () => {
    createComponent();

    expect(findActiveTab().text()).toBe('All');
  });

  it('Another tab can be preselected by the user', () => {
    createComponent({
      props: {
        value: {
          ...mockSearch,
          runnerType: INSTANCE_TYPE,
        },
      },
    });

    expect(findActiveTab().text()).toBe('Instance');
  });

  describe('When the user selects a tab', () => {
    const emittedValue = () => wrapper.emitted('input')[0][0];

    beforeEach(() => {
      createComponent();
      findTabs().at(2).vm.$emit('click');
    });

    it(`Runner type is emitted`, () => {
      expect(emittedValue()).toEqual({
        ...mockSearch,
        runnerType: GROUP_TYPE,
      });
    });

    it('Runner type is selected', async () => {
      const newValue = emittedValue();
      await wrapper.setProps({ value: newValue });

      expect(findActiveTab().text()).toBe('Group');
    });
  });

  describe('Component API', () => {
    describe('When .refetch() is called', () => {
      let mockRefetch;

      beforeEach(() => {
        mockRefetch = jest.fn();

        createComponent({
          stubs: {
            RunnerCount: {
              methods: {
                refetch: mockRefetch,
              },
              render() {},
            },
          },
        });

        wrapper.vm.refetch();
      });

      it('refetch is called for each count', () => {
        expect(mockRefetch).toHaveBeenCalledTimes(4);
      });
    });
  });
});
