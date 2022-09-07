import { GlLoadingIcon } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import { dispatch } from 'codesandbox-api';
import { SandpackClient } from '@codesandbox/sandpack-client';
import Vuex from 'vuex';
import waitForPromises from 'helpers/wait_for_promises';
import Clientside from '~/ide/components/preview/clientside.vue';
import { PING_USAGE_PREVIEW_KEY, PING_USAGE_PREVIEW_SUCCESS_KEY } from '~/ide/constants';
import eventHub from '~/ide/eventhub';

jest.mock('@codesandbox/sandpack-client', () => ({
  SandpackClient: jest.fn(),
}));

Vue.use(Vuex);

const dummyPackageJson = () => ({
  raw: JSON.stringify({
    main: 'index.js',
  }),
});
const expectedSandpackOptions = () => ({
  files: {},
  entry: '/index.js',
  showOpenInCodeSandbox: true,
});
const expectedSandpackSettings = () => ({
  fileResolver: {
    isFile: expect.any(Function),
    readFile: expect.any(Function),
  },
});

describe('IDE clientside preview', () => {
  let wrapper;
  let store;
  const storeActions = {
    getFileData: jest.fn().mockReturnValue(Promise.resolve({})),
    getRawFileData: jest.fn().mockReturnValue(Promise.resolve('')),
  };
  const storeClientsideActions = {
    pingUsage: jest.fn().mockReturnValue(Promise.resolve({})),
  };
  const dispatchCodesandboxReady = () => dispatch({ type: 'done' });

  const createComponent = ({ state, getters } = {}) => {
    store = new Vuex.Store({
      state: {
        entries: {},
        links: {},
        ...state,
      },
      getters: {
        packageJson: () => '',
        currentProject: () => ({
          visibility: 'public',
        }),
        ...getters,
      },
      actions: storeActions,
      modules: {
        clientside: {
          namespaced: true,
          actions: storeClientsideActions,
        },
      },
    });

    wrapper = shallowMount(Clientside, {
      store,
    });
  };

  const createInitializedComponent = () => {
    createComponent();
    // setData usage is discouraged. See https://gitlab.com/groups/gitlab-org/-/epics/7330 for details
    // eslint-disable-next-line no-restricted-syntax
    wrapper.setData({
      sandpackReady: true,
      client: {
        cleanup: jest.fn(),
        updatePreview: jest.fn(),
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  describe('without main entry', () => {
    it('creates sandpack client', () => {
      createComponent();
      expect(SandpackClient).not.toHaveBeenCalled();
    });
  });
  describe('with main entry', () => {
    beforeEach(() => {
      createComponent({ getters: { packageJson: dummyPackageJson } });

      return waitForPromises();
    });

    it('creates sandpack client', () => {
      expect(SandpackClient).toHaveBeenCalledWith(
        '#ide-preview',
        expectedSandpackOptions(),
        expectedSandpackSettings(),
      );
    });

    it('pings usage', () => {
      expect(storeClientsideActions.pingUsage).toHaveBeenCalledTimes(1);
      expect(storeClientsideActions.pingUsage).toHaveBeenCalledWith(
        expect.anything(),
        PING_USAGE_PREVIEW_KEY,
      );
    });

    it('pings usage success', async () => {
      dispatchCodesandboxReady();
      await nextTick();
      expect(storeClientsideActions.pingUsage).toHaveBeenCalledTimes(2);
      expect(storeClientsideActions.pingUsage).toHaveBeenCalledWith(
        expect.anything(),
        PING_USAGE_PREVIEW_SUCCESS_KEY,
      );
    });
  });

  describe('with codesandboxBundlerUrl', () => {
    const TEST_BUNDLER_URL = 'https://test.gitlab-static.test';

    beforeEach(() => {
      createComponent({
        getters: { packageJson: dummyPackageJson },
        state: { codesandboxBundlerUrl: TEST_BUNDLER_URL },
      });

      return waitForPromises();
    });

    it('creates sandpack client with bundlerURL', () => {
      expect(SandpackClient).toHaveBeenCalledWith('#ide-preview', expectedSandpackOptions(), {
        ...expectedSandpackSettings(),
        bundlerURL: TEST_BUNDLER_URL,
      });
    });
  });

  describe('with codesandboxBundlerURL', () => {
    beforeEach(() => {
      createComponent({ getters: { packageJson: dummyPackageJson } });

      return waitForPromises();
    });

    it('creates sandpack client', () => {
      expect(SandpackClient).toHaveBeenCalledWith(
        '#ide-preview',
        {
          files: {},
          entry: '/index.js',
          showOpenInCodeSandbox: true,
        },
        {
          fileResolver: {
            isFile: expect.any(Function),
            readFile: expect.any(Function),
          },
        },
      );
    });
  });

  describe('computed', () => {
    describe('normalizedEntries', () => {
      it('returns flattened list of blobs with content', () => {
        createComponent({
          state: {
            entries: {
              'index.js': { type: 'blob', raw: 'test' },
              'index2.js': { type: 'blob', content: 'content' },
              tree: { type: 'tree' },
              empty: { type: 'blob' },
            },
          },
        });

        expect(wrapper.vm.normalizedEntries).toEqual({
          '/index.js': {
            code: 'test',
          },
          '/index2.js': {
            code: 'content',
          },
        });
      });
    });

    describe('mainEntry', () => {
      it('returns false when package.json is empty', () => {
        createComponent();
        expect(wrapper.vm.mainEntry).toBe(false);
      });

      it('returns main key from package.json', () => {
        createComponent({ getters: { packageJson: dummyPackageJson } });
        expect(wrapper.vm.mainEntry).toBe('index.js');
      });
    });

    describe('showPreview', () => {
      it('returns false if no mainEntry', () => {
        createComponent();
        expect(wrapper.vm.showPreview).toBe(false);
      });

      it('returns false if loading and mainEntry exists', () => {
        createComponent({ getters: { packageJson: dummyPackageJson } });
        // setData usage is discouraged. See https://gitlab.com/groups/gitlab-org/-/epics/7330 for details
        // eslint-disable-next-line no-restricted-syntax
        wrapper.setData({ loading: true });

        expect(wrapper.vm.showPreview).toBe(false);
      });

      it('returns true if not loading and mainEntry exists', () => {
        createComponent({ getters: { packageJson: dummyPackageJson } });
        // setData usage is discouraged. See https://gitlab.com/groups/gitlab-org/-/epics/7330 for details
        // eslint-disable-next-line no-restricted-syntax
        wrapper.setData({ loading: false });

        expect(wrapper.vm.showPreview).toBe(true);
      });
    });

    describe('showEmptyState', () => {
      it('returns true if no mainEntry exists', () => {
        createComponent();
        // setData usage is discouraged. See https://gitlab.com/groups/gitlab-org/-/epics/7330 for details
        // eslint-disable-next-line no-restricted-syntax
        wrapper.setData({ loading: false });
        expect(wrapper.vm.showEmptyState).toBe(true);
      });

      it('returns false if loading', () => {
        createComponent();
        // setData usage is discouraged. See https://gitlab.com/groups/gitlab-org/-/epics/7330 for details
        // eslint-disable-next-line no-restricted-syntax
        wrapper.setData({ loading: true });

        expect(wrapper.vm.showEmptyState).toBe(false);
      });

      it('returns false if not loading and mainEntry exists', () => {
        createComponent({ getters: { packageJson: dummyPackageJson } });
        // setData usage is discouraged. See https://gitlab.com/groups/gitlab-org/-/epics/7330 for details
        // eslint-disable-next-line no-restricted-syntax
        wrapper.setData({ loading: false });

        expect(wrapper.vm.showEmptyState).toBe(false);
      });
    });

    describe('showOpenInCodeSandbox', () => {
      it('returns true when visibility is public', () => {
        createComponent({ getters: { currentProject: () => ({ visibility: 'public' }) } });

        expect(wrapper.vm.showOpenInCodeSandbox).toBe(true);
      });

      it('returns false when visibility is private', () => {
        createComponent({ getters: { currentProject: () => ({ visibility: 'private' }) } });

        expect(wrapper.vm.showOpenInCodeSandbox).toBe(false);
      });
    });

    describe('sandboxOpts', () => {
      beforeEach(() => {
        createComponent({
          state: {
            entries: {
              'index.js': { type: 'blob', raw: 'test' },
              'package.json': dummyPackageJson(),
            },
          },
          getters: {
            packageJson: dummyPackageJson,
          },
        });
      });

      it('returns sandbox options', () => {
        expect(wrapper.vm.sandboxOpts).toEqual({
          files: {
            '/index.js': {
              code: 'test',
            },
            '/package.json': {
              code: '{"main":"index.js"}',
            },
          },
          entry: '/index.js',
          showOpenInCodeSandbox: true,
        });
      });
    });
  });

  describe('methods', () => {
    describe('loadFileContent', () => {
      beforeEach(() => {
        createComponent();
        return wrapper.vm.loadFileContent('package.json');
      });

      it('calls getFileData', () => {
        expect(storeActions.getFileData).toHaveBeenCalledWith(expect.any(Object), {
          path: 'package.json',
          makeFileActive: false,
        });
      });

      it('calls getRawFileData', () => {
        expect(storeActions.getRawFileData).toHaveBeenCalledWith(expect.any(Object), {
          path: 'package.json',
        });
      });
    });

    describe('update', () => {
      it('initializes client if client is empty', () => {
        createComponent({ getters: { packageJson: dummyPackageJson } });
        // setData usage is discouraged. See https://gitlab.com/groups/gitlab-org/-/epics/7330 for details
        // eslint-disable-next-line no-restricted-syntax
        wrapper.setData({ sandpackReady: true });
        wrapper.vm.update();

        return waitForPromises().then(() => {
          expect(SandpackClient).toHaveBeenCalled();
        });
      });

      it('calls updatePreview', () => {
        createInitializedComponent();

        wrapper.vm.update();

        expect(wrapper.vm.client.updatePreview).toHaveBeenCalledWith(wrapper.vm.sandboxOpts);
      });
    });

    describe('on ide.files.change event', () => {
      beforeEach(() => {
        createInitializedComponent();

        eventHub.$emit('ide.files.change');
      });

      it('calls updatePreview', () => {
        expect(wrapper.vm.client.updatePreview).toHaveBeenCalledWith(wrapper.vm.sandboxOpts);
      });
    });
  });

  describe('template', () => {
    it('renders ide-preview element when showPreview is true', async () => {
      createComponent({ getters: { packageJson: dummyPackageJson } });
      // setData usage is discouraged. See https://gitlab.com/groups/gitlab-org/-/epics/7330 for details
      // eslint-disable-next-line no-restricted-syntax
      wrapper.setData({ loading: false });

      await nextTick();
      expect(wrapper.find('#ide-preview').exists()).toBe(true);
    });

    it('renders empty state', async () => {
      createComponent();
      // setData usage is discouraged. See https://gitlab.com/groups/gitlab-org/-/epics/7330 for details
      // eslint-disable-next-line no-restricted-syntax
      wrapper.setData({ loading: false });

      await nextTick();
      expect(wrapper.text()).toContain(
        'Preview your web application using Web IDE client-side evaluation.',
      );
    });

    it('renders loading icon', async () => {
      createComponent();
      // setData usage is discouraged. See https://gitlab.com/groups/gitlab-org/-/epics/7330 for details
      // eslint-disable-next-line no-restricted-syntax
      wrapper.setData({ loading: true });

      await nextTick();
      expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(true);
    });
  });

  describe('when destroyed', () => {
    let spy;

    beforeEach(() => {
      createInitializedComponent();
      spy = wrapper.vm.client.updatePreview;
      wrapper.destroy();
    });

    it('does not call updatePreview', () => {
      expect(spy).not.toHaveBeenCalled();
    });
  });
});
