import { shallowMount } from '@vue/test-utils';
import { GlLoadingIcon } from '@gitlab/ui';
import LastCommit from '~/repository/components/last_commit.vue';
import UserAvatarLink from '~/vue_shared/components/user_avatar/user_avatar_link.vue';

let vm;

function createCommitData(data = {}) {
  const defaultData = {
    sha: '123456789',
    title: 'Commit title',
    message: 'Commit message',
    webUrl: 'https://test.com/commit/123',
    authoredDate: '2019-01-01',
    author: {
      name: 'Test',
      avatarUrl: 'https://test.com',
      webUrl: 'https://test.com/test',
    },
    pipeline: {
      detailedStatus: {
        detailsPath: 'https://test.com/pipeline',
        icon: 'failed',
        tooltip: 'failed',
        text: 'failed',
        group: {},
      },
    },
  };
  return Object.assign(defaultData, data);
}

function factory(commit = createCommitData(), loading = false) {
  vm = shallowMount(LastCommit, {
    mocks: {
      $apollo: {
        queries: {
          commit: {
            loading: true,
          },
        },
      },
    },
  });
  vm.setData({ commit });
  vm.vm.$apollo.queries.commit.loading = loading;
}

const emptyMessageClass = 'font-italic';

describe('Repository last commit component', () => {
  afterEach(() => {
    vm.destroy();
  });

  it.each`
    loading  | label
    ${true}  | ${'shows'}
    ${false} | ${'hides'}
  `('$label when loading icon $loading is true', ({ loading }) => {
    factory(createCommitData(), loading);

    return vm.vm.$nextTick(() => {
      expect(vm.find(GlLoadingIcon).exists()).toBe(loading);
    });
  });

  it('renders commit widget', () => {
    factory();

    return vm.vm.$nextTick(() => {
      expect(vm.element).toMatchSnapshot();
    });
  });

  it('renders short commit ID', () => {
    factory();

    return vm.vm.$nextTick(() => {
      expect(vm.find('.label-monospace').text()).toEqual('12345678');
    });
  });

  it('hides pipeline components when pipeline does not exist', () => {
    factory(createCommitData({ pipeline: null }));

    return vm.vm.$nextTick(() => {
      expect(vm.find('.js-commit-pipeline').exists()).toBe(false);
    });
  });

  it('renders pipeline components', () => {
    factory();

    return vm.vm.$nextTick(() => {
      expect(vm.find('.js-commit-pipeline').exists()).toBe(true);
    });
  });

  it('hides author component when author does not exist', () => {
    factory(createCommitData({ author: null }));

    return vm.vm.$nextTick(() => {
      expect(vm.find('.js-user-link').exists()).toBe(false);
      expect(vm.find(UserAvatarLink).exists()).toBe(false);
    });
  });

  it('does not render description expander when description is null', () => {
    factory(createCommitData({ description: null }));

    return vm.vm.$nextTick(() => {
      expect(vm.find('.text-expander').exists()).toBe(false);
      expect(vm.find('.commit-row-description').exists()).toBe(false);
    });
  });

  it('expands commit description when clicking expander', () => {
    factory(createCommitData({ description: 'Test description' }));

    return vm.vm
      .$nextTick()
      .then(() => {
        vm.find('.text-expander').vm.$emit('click');
        return vm.vm.$nextTick();
      })
      .then(() => {
        expect(vm.find('.commit-row-description').isVisible()).toBe(true);
        expect(vm.find('.text-expander').classes('open')).toBe(true);
      });
  });

  it('renders the signature HTML as returned by the backend', () => {
    factory(createCommitData({ signatureHtml: '<button>Verified</button>' }));

    return vm.vm.$nextTick().then(() => {
      expect(vm.element).toMatchSnapshot();
    });
  });

  it('sets correct CSS class if the commit message is empty', () => {
    factory(createCommitData({ message: '' }));

    return vm.vm.$nextTick().then(() => {
      expect(vm.find('.item-title').classes()).toContain(emptyMessageClass);
    });
  });
});
