import { shallowMount } from '@vue/test-utils';
import DivergenceGraph from '~/branches/components/divergence_graph.vue';
import GraphBar from '~/branches/components/graph_bar.vue';

let vm;

function factory(propsData = {}) {
  vm = shallowMount(DivergenceGraph, { propsData });
}

describe('Branch divergence graph component', () => {
  afterEach(() => {
    vm.destroy();
  });

  it('renders ahead and behind count', () => {
    factory({
      defaultBranch: 'master',
      aheadCount: 10,
      behindCount: 10,
      maxCommits: 100,
    });

    expect(vm.findAll(GraphBar).length).toBe(2);
    expect(vm.element).toMatchSnapshot();
  });

  it('sets title for ahead and behind count', () => {
    factory({
      defaultBranch: 'master',
      aheadCount: 10,
      behindCount: 10,
      maxCommits: 100,
    });

    expect(vm.attributes('title')).toBe('10 commits behind master, 10 commits ahead');
  });

  it('renders distance count', () => {
    factory({
      defaultBranch: 'master',
      aheadCount: 0,
      behindCount: 0,
      distance: 900,
      maxCommits: 100,
    });

    expect(vm.findAll(GraphBar).length).toBe(1);
    expect(vm.element).toMatchSnapshot();
  });

  it.each`
    distance | titleText
    ${900}   | ${'900'}
    ${1100}  | ${'999+'}
  `('sets title for $distance as $titleText', ({ distance, titleText }) => {
    factory({
      defaultBranch: 'master',
      aheadCount: 0,
      behindCount: 0,
      distance,
      maxCommits: 100,
    });

    expect(vm.attributes('title')).toBe(`More than ${titleText} commits different with master`);
  });
});
