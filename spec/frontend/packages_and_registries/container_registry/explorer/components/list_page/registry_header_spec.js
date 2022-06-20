import { GlSprintf, GlLink } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import Component from '~/packages_and_registries/container_registry/explorer/components/list_page/registry_header.vue';
import {
  CONTAINER_REGISTRY_TITLE,
  LIST_INTRO_TEXT,
  EXPIRATION_POLICY_DISABLED_TEXT,
  SET_UP_CLEANUP,
} from '~/packages_and_registries/container_registry/explorer/constants';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';

jest.mock('~/lib/utils/datetime_utility', () => ({
  approximateDuration: jest.fn(),
  calculateRemainingMilliseconds: jest.fn(),
}));

describe('registry_header', () => {
  let wrapper;

  const findTitleArea = () => wrapper.find(TitleArea);
  const findCommandsSlot = () => wrapper.find('[data-testid="commands-slot"]');
  const findImagesCountSubHeader = () => wrapper.find('[data-testid="images-count"]');
  const findExpirationPolicySubHeader = () => wrapper.find('[data-testid="expiration-policy"]');
  const findSetupCleanUpLink = () => wrapper.findComponent(GlLink);

  const mountComponent = async (propsData, slots) => {
    wrapper = shallowMount(Component, {
      stubs: {
        GlSprintf,
        TitleArea,
      },
      propsData,
      slots,
    });
    await nextTick();
  };

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
  });

  describe('header', () => {
    it('has a title', () => {
      mountComponent({ metadataLoading: true });

      expect(findTitleArea().props()).toMatchObject({
        title: CONTAINER_REGISTRY_TITLE,
        metadataLoading: true,
      });
    });

    it('has a commands slot', () => {
      mountComponent(null, { commands: '<div data-testid="commands-slot">baz</div>' });

      expect(findCommandsSlot().text()).toBe('baz');
    });

    describe('sub header parts', () => {
      describe('images count', () => {
        it('exists', async () => {
          await mountComponent({ imagesCount: 1 });

          expect(findImagesCountSubHeader().exists()).toBe(true);
        });

        it('when there is one image', async () => {
          await mountComponent({ imagesCount: 1 });

          expect(findImagesCountSubHeader().props()).toMatchObject({
            text: '1 Image repository',
            icon: 'container-image',
          });
        });

        it('when there is more than one image', async () => {
          await mountComponent({ imagesCount: 3 });

          expect(findImagesCountSubHeader().props('text')).toBe('3 Image repositories');
        });
      });

      describe('expiration policy', () => {
        it('when is disabled', async () => {
          await mountComponent({
            expirationPolicy: { enabled: false },
            expirationPolicyHelpPagePath: 'foo',
            imagesCount: 1,
          });

          const text = findExpirationPolicySubHeader();

          expect(text.exists()).toBe(true);
          expect(text.props()).toMatchObject({
            text: EXPIRATION_POLICY_DISABLED_TEXT,
            icon: 'expire',
            size: 'xl',
          });
        });

        it('when is enabled', async () => {
          await mountComponent({
            expirationPolicy: { enabled: true },
            expirationPolicyHelpPagePath: 'foo',
            showCleanupPolicyLink: true,
            imagesCount: 1,
          });

          const text = findExpirationPolicySubHeader();
          const cleanupLink = findSetupCleanUpLink();

          expect(text.exists()).toBe(true);
          expect(text.props('text')).toBe('Expiration policy will run in ');
          expect(cleanupLink.exists()).toBe(true);
          expect(cleanupLink.text()).toBe(SET_UP_CLEANUP);
        });
        it('when the expiration policy is completely disabled', async () => {
          await mountComponent({
            expirationPolicy: { enabled: true },
            expirationPolicyHelpPagePath: 'foo',
            imagesCount: 1,
            hideExpirationPolicyData: true,
          });

          const text = findExpirationPolicySubHeader();
          expect(text.exists()).toBe(false);
        });
      });
    });
  });

  describe('info messages', () => {
    describe('default message', () => {
      it('is correctly bound to title_area props', () => {
        mountComponent({ helpPagePath: 'foo' });

        expect(findTitleArea().props('infoMessages')).toEqual([
          { text: LIST_INTRO_TEXT, link: 'foo' },
        ]);
      });
    });
  });
});
