import Vuex from 'vuex';
import { shallowMount, createLocalVue } from '@vue/test-utils';
import createState from '~/code_navigation/store/state';
import App from '~/code_navigation/components/app.vue';
import Popover from '~/code_navigation/components/popover.vue';

const localVue = createLocalVue();
const fetchData = jest.fn();
const showDefinition = jest.fn();
let wrapper;

localVue.use(Vuex);

function factory(initialState = {}) {
  const store = new Vuex.Store({
    state: {
      ...createState(),
      ...initialState,
    },
    actions: {
      fetchData,
      showDefinition,
    },
  });

  wrapper = shallowMount(App, { store, localVue });
}

describe('Code navigation app component', () => {
  afterEach(() => {
    wrapper.destroy();
  });

  it('fetches data on mount', () => {
    factory();

    expect(fetchData).toHaveBeenCalled();
  });

  it('hides popover when no definition set', () => {
    factory();

    expect(wrapper.find(Popover).exists()).toBe(false);
  });

  it('renders popover when definition set', () => {
    factory({
      currentDefinition: { hover: 'console' },
      currentDefinitionPosition: { x: 0 },
    });

    expect(wrapper.find(Popover).exists()).toBe(true);
  });

  it('calls showDefinition when clicking blob viewer', () => {
    setFixtures('<div class="blob-viewer"></div>');

    factory();

    document.querySelector('.blob-viewer').click();

    expect(showDefinition).toHaveBeenCalled();
  });
});
