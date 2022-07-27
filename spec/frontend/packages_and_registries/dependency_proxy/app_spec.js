import {
  GlAlert,
  GlDropdown,
  GlDropdownItem,
  GlFormInputGroup,
  GlFormGroup,
  GlModal,
  GlSkeletonLoader,
  GlSprintf,
  GlEmptyState,
} from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import MockAdapter from 'axios-mock-adapter';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stripTypenames } from 'helpers/graphql_helpers';
import waitForPromises from 'helpers/wait_for_promises';
import { GRAPHQL_PAGE_SIZE } from '~/packages_and_registries/dependency_proxy/constants';
import axios from '~/lib/utils/axios_utils';

import DependencyProxyApp from '~/packages_and_registries/dependency_proxy/app.vue';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import ManifestsList from '~/packages_and_registries/dependency_proxy/components/manifests_list.vue';

import getDependencyProxyDetailsQuery from '~/packages_and_registries/dependency_proxy/graphql/queries/get_dependency_proxy_details.query.graphql';

import { proxyDetailsQuery, proxyData, pagination, proxyManifests } from './mock_data';

const dummyApiVersion = 'v3000';
const dummyGrouptId = 1;
const dummyUrlRoot = '/gitlab';
const dummyGon = {
  api_version: dummyApiVersion,
  relative_url_root: dummyUrlRoot,
};
let originalGon;
const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/${dummyGrouptId}/dependency_proxy/cache`;

Vue.use(VueApollo);

describe('DependencyProxyApp', () => {
  let wrapper;
  let apolloProvider;
  let resolver;
  let mock;

  const provideDefaults = {
    groupPath: 'gitlab-org',
    groupId: dummyGrouptId,
    noManifestsIllustration: 'noManifestsIllustration',
  };

  function createComponent({ provide = provideDefaults } = {}) {
    const requestHandlers = [[getDependencyProxyDetailsQuery, resolver]];

    apolloProvider = createMockApollo(requestHandlers);

    wrapper = shallowMountExtended(DependencyProxyApp, {
      apolloProvider,
      provide,
      stubs: {
        GlAlert,
        GlDropdown,
        GlDropdownItem,
        GlFormInputGroup,
        GlFormGroup,
        GlModal,
        GlSprintf,
        TitleArea,
      },
    });
  }

  const findClipBoardButton = () => wrapper.findComponent(ClipboardButton);
  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findFormInputGroup = () => wrapper.findComponent(GlFormInputGroup);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findMainArea = () => wrapper.findByTestId('main-area');
  const findProxyCountText = () => wrapper.findByTestId('proxy-count');
  const findManifestList = () => wrapper.findComponent(ManifestsList);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findClearCacheDropdownList = () => wrapper.findComponent(GlDropdown);
  const findClearCacheModal = () => wrapper.findComponent(GlModal);
  const findClearCacheAlert = () => wrapper.findComponent(GlAlert);

  beforeEach(() => {
    resolver = jest.fn().mockResolvedValue(proxyDetailsQuery());

    originalGon = window.gon;
    window.gon = { ...dummyGon };

    mock = new MockAdapter(axios);
    mock.onDelete(expectedUrl).reply(202, {});
  });

  afterEach(() => {
    wrapper.destroy();
    window.gon = originalGon;
    mock.restore();
  });

  describe('when the dependency proxy is available', () => {
    describe('when is loading', () => {
      it('renders the skeleton loader', () => {
        createComponent();

        expect(findSkeletonLoader().exists()).toBe(true);
      });

      it('does not render a form group with label', () => {
        createComponent();

        expect(findFormGroup().exists()).toBe(false);
      });

      it('does not show the main section', () => {
        createComponent();

        expect(findMainArea().exists()).toBe(false);
      });
    });

    describe('when the app is loaded', () => {
      describe('when the dependency proxy is enabled', () => {
        beforeEach(() => {
          createComponent();
          return waitForPromises();
        });

        it('renders the main area', () => {
          expect(findMainArea().exists()).toBe(true);
        });

        it('renders a form group with a label', () => {
          expect(findFormGroup().attributes('label')).toBe(
            DependencyProxyApp.i18n.proxyImagePrefix,
          );
        });

        it('renders a form input group', () => {
          expect(findFormInputGroup().exists()).toBe(true);
          expect(findFormInputGroup().props('value')).toBe(proxyData().dependencyProxyImagePrefix);
        });

        it('form input group has a clipboard button', () => {
          expect(findClipBoardButton().exists()).toBe(true);
          expect(findClipBoardButton().props()).toMatchObject({
            text: proxyData().dependencyProxyImagePrefix,
            title: DependencyProxyApp.i18n.copyImagePrefixText,
          });
        });

        it('form group has a description with proxy count', () => {
          expect(findProxyCountText().text()).toBe('Contains 2 blobs of images (1024 Bytes)');
        });

        describe('manifest lists', () => {
          describe('when there are no manifests', () => {
            beforeEach(() => {
              resolver = jest.fn().mockResolvedValue(
                proxyDetailsQuery({
                  extend: { dependencyProxyManifests: { nodes: [], pageInfo: pagination() } },
                }),
              );
              createComponent();

              return waitForPromises();
            });

            it('shows the empty state message', () => {
              expect(findEmptyState().props()).toMatchObject({
                svgPath: provideDefaults.noManifestsIllustration,
                title: DependencyProxyApp.i18n.noManifestTitle,
              });
            });

            it('hides the list', () => {
              expect(findManifestList().exists()).toBe(false);
            });
          });

          describe('when there are manifests', () => {
            it('hides the empty state message', () => {
              expect(findEmptyState().exists()).toBe(false);
            });

            it('shows list', () => {
              expect(findManifestList().props()).toMatchObject({
                manifests: proxyManifests(),
                pagination: stripTypenames(pagination()),
              });
            });

            it('prev-page event on list fetches the previous page', async () => {
              findManifestList().vm.$emit('prev-page');
              await waitForPromises();

              expect(resolver).toHaveBeenCalledWith({
                before: pagination().startCursor,
                first: null,
                fullPath: provideDefaults.groupPath,
                last: GRAPHQL_PAGE_SIZE,
              });
            });

            it('next-page event on list fetches the next page', async () => {
              findManifestList().vm.$emit('next-page');
              await waitForPromises();

              expect(resolver).toHaveBeenCalledWith({
                after: pagination().endCursor,
                first: GRAPHQL_PAGE_SIZE,
                fullPath: provideDefaults.groupPath,
              });
            });

            describe('triggering page event on list', () => {
              it('re-renders the skeleton loader', async () => {
                findManifestList().vm.$emit('next-page');
                await nextTick();

                expect(findSkeletonLoader().exists()).toBe(true);
              });

              it('renders form group with label', async () => {
                findManifestList().vm.$emit('next-page');
                await nextTick();

                expect(findFormGroup().attributes('label')).toEqual(
                  expect.stringMatching(DependencyProxyApp.i18n.proxyImagePrefix),
                );
              });

              it('does not show the main section', async () => {
                findManifestList().vm.$emit('next-page');
                await nextTick();

                expect(findMainArea().exists()).toBe(false);
              });
            });

            it('shows the clear cache dropdown list', () => {
              expect(findClearCacheDropdownList().exists()).toBe(true);

              const clearCacheDropdownItem = findClearCacheDropdownList().findComponent(
                GlDropdownItem,
              );

              expect(clearCacheDropdownItem.text()).toBe('Clear cache');
            });

            it('shows the clear cache confirmation modal', () => {
              const modal = findClearCacheModal();

              expect(modal.find('.modal-title').text()).toContain('Clear 2 images from cache?');
              expect(modal.props('actionPrimary').text).toBe('Clear cache');
            });

            it('submits the clear cache request', async () => {
              findClearCacheModal().vm.$emit('primary', { preventDefault: jest.fn() });

              await waitForPromises();

              expect(findClearCacheAlert().exists()).toBe(true);
              expect(findClearCacheAlert().text()).toBe(
                'All items in the cache are scheduled for removal.',
              );
            });
          });
        });
      });
    });
  });
});
