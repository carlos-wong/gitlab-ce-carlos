import { GlIcon, GlSprintf, GlSkeletonLoader, GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { mockTracking } from 'helpers/tracking_helper';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import DeleteButton from '~/packages_and_registries/container_registry/explorer/components/delete_button.vue';
import CleanupStatus from '~/packages_and_registries/container_registry/explorer/components/list_page/cleanup_status.vue';
import Component from '~/packages_and_registries/container_registry/explorer/components/list_page/image_list_row.vue';
import {
  ROW_SCHEDULED_FOR_DELETION,
  LIST_DELETE_BUTTON_DISABLED,
  REMOVE_REPOSITORY_LABEL,
  IMAGE_DELETE_SCHEDULED_STATUS,
  IMAGE_MIGRATING_STATE,
  SCHEDULED_STATUS,
  COPY_IMAGE_PATH_TITLE,
} from '~/packages_and_registries/container_registry/explorer/constants';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import ListItem from '~/vue_shared/components/registry/list_item.vue';
import { imagesListResponse } from '../../mock_data';
import { RouterLink } from '../../stubs';

describe('Image List Row', () => {
  let wrapper;
  const [item] = imagesListResponse;

  const findDetailsLink = () => wrapper.find('[data-testid="details-link"]');
  const findTagsCount = () => wrapper.find('[data-testid="tags-count"]');
  const findDeleteBtn = () => wrapper.findComponent(DeleteButton);
  const findClipboardButton = () => wrapper.findComponent(ClipboardButton);
  const findCleanupStatus = () => wrapper.findComponent(CleanupStatus);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findListItemComponent = () => wrapper.findComponent(ListItem);
  const findShowFullPathButton = () => wrapper.findComponent(GlButton);

  const mountComponent = (props, features = {}) => {
    wrapper = shallowMount(Component, {
      stubs: {
        RouterLink,
        GlSprintf,
        ListItem,
        GlButton,
      },
      propsData: {
        item,
        ...props,
      },
      provide: {
        config: {},
        glFeatures: {
          ...features,
        },
      },
      directives: {
        GlTooltip: createMockDirective(),
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
  });

  describe('list item component', () => {
    describe('tooltip', () => {
      it(`the title is ${ROW_SCHEDULED_FOR_DELETION}`, () => {
        mountComponent();

        const tooltip = getBinding(wrapper.element, 'gl-tooltip');
        expect(tooltip).toBeDefined();
        expect(tooltip.value.title).toBe(ROW_SCHEDULED_FOR_DELETION);
      });

      it('is disabled when item is being deleted', () => {
        mountComponent({ item: { ...item, status: IMAGE_DELETE_SCHEDULED_STATUS } });

        const tooltip = getBinding(wrapper.element, 'gl-tooltip');
        expect(tooltip.value.disabled).toBe(false);
      });
    });

    it('is disabled when the item is in deleting status', () => {
      mountComponent({ item: { ...item, status: IMAGE_DELETE_SCHEDULED_STATUS } });

      expect(findListItemComponent().props('disabled')).toBe(true);
    });
  });

  describe('image title and path', () => {
    it('contains a link to the details page', () => {
      mountComponent();

      const link = findDetailsLink();
      expect(link.text()).toBe(item.path);
      expect(findDetailsLink().props('to')).toMatchObject({
        name: 'details',
        params: {
          id: getIdFromGraphQLId(item.id),
        },
      });
    });

    it('when the image has no name lists the path', () => {
      mountComponent({ item: { ...item, name: '' } });

      expect(findDetailsLink().text()).toBe(item.path);
    });

    it('contains a clipboard button', () => {
      mountComponent();
      const button = findClipboardButton();
      expect(button.exists()).toBe(true);
      expect(button.props('text')).toBe(item.location);
      expect(button.props('title')).toBe(COPY_IMAGE_PATH_TITLE);
    });

    describe('cleanup status component', () => {
      it.each`
        expirationPolicyCleanupStatus | shown
        ${null}                       | ${false}
        ${SCHEDULED_STATUS}           | ${true}
      `(
        'when expirationPolicyCleanupStatus is $expirationPolicyCleanupStatus it is $shown that the component exists',
        ({ expirationPolicyCleanupStatus, shown }) => {
          mountComponent({ item: { ...item, expirationPolicyCleanupStatus } });

          expect(findCleanupStatus().exists()).toBe(shown);

          if (shown) {
            expect(findCleanupStatus().props()).toMatchObject({
              status: expirationPolicyCleanupStatus,
            });
          }
        },
      );
    });

    describe('when the item is deleting', () => {
      beforeEach(() => {
        mountComponent({ item: { ...item, status: IMAGE_DELETE_SCHEDULED_STATUS } });
      });

      it('the router link is disabled', () => {
        // we check the event prop as is the only workaround to disable a router link
        expect(findDetailsLink().props('event')).toBe('');
      });
      it('the clipboard button is disabled', () => {
        expect(findClipboardButton().attributes('disabled')).toBe('true');
      });
    });

    describe('when containerRegistryShowShortenedPath feature enabled', () => {
      let trackingSpy;

      beforeEach(() => {
        mountComponent({}, { containerRegistryShowShortenedPath: true });
        trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      });

      it('renders shortened name of image', () => {
        expect(findShowFullPathButton().exists()).toBe(true);
        expect(findDetailsLink().text()).toBe('gitlab-test/rails-12009');
      });

      it('clicking on shortened name of image hides the button & shows full path', async () => {
        const btn = findShowFullPathButton();
        const mockFocusFn = jest.fn();
        wrapper.vm.$refs.imageName.$el.focus = mockFocusFn;

        await btn.trigger('click');

        expect(findShowFullPathButton().exists()).toBe(false);
        expect(findDetailsLink().text()).toBe(item.path);
        expect(mockFocusFn).toHaveBeenCalled();
        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_show_full_path', {
          label: 'registry_image_list',
        });
      });
    });
  });

  describe('delete button', () => {
    it('exists', () => {
      mountComponent();
      expect(findDeleteBtn().exists()).toBe(true);
    });

    it('has the correct props', () => {
      mountComponent();

      expect(findDeleteBtn().props()).toMatchObject({
        title: REMOVE_REPOSITORY_LABEL,
        tooltipDisabled: item.canDelete,
        tooltipTitle: LIST_DELETE_BUTTON_DISABLED,
      });
    });

    it('emits a delete event', () => {
      mountComponent();

      findDeleteBtn().vm.$emit('delete');
      expect(wrapper.emitted('delete')).toEqual([[item]]);
    });

    it.each`
      canDelete | status                           | state
      ${false}  | ${''}                            | ${true}
      ${false}  | ${IMAGE_DELETE_SCHEDULED_STATUS} | ${true}
      ${true}   | ${IMAGE_DELETE_SCHEDULED_STATUS} | ${true}
      ${true}   | ${''}                            | ${false}
    `(
      'disabled is $state when canDelete is $canDelete and status is $status',
      ({ canDelete, status, state }) => {
        mountComponent({ item: { ...item, canDelete, status } });

        expect(findDeleteBtn().props('disabled')).toBe(state);
      },
    );

    it('is disabled when migrationState is importing', () => {
      mountComponent({ item: { ...item, migrationState: IMAGE_MIGRATING_STATE } });

      expect(findDeleteBtn().props('disabled')).toBe(true);
    });
  });

  describe('tags count', () => {
    it('exists', () => {
      mountComponent();
      expect(findTagsCount().exists()).toBe(true);
    });

    it('contains a tag icon', () => {
      mountComponent();
      const icon = findTagsCount().find(GlIcon);
      expect(icon.exists()).toBe(true);
      expect(icon.props('name')).toBe('tag');
    });

    describe('loading state', () => {
      it('shows a loader when metadataLoading is true', () => {
        mountComponent({ metadataLoading: true });

        expect(findSkeletonLoader().exists()).toBe(true);
      });

      it('hides the tags count while loading', () => {
        mountComponent({ metadataLoading: true });

        expect(findTagsCount().exists()).toBe(false);
      });
    });

    describe('tags count text', () => {
      it('with one tag in the image', () => {
        mountComponent({ item: { ...item, tagsCount: 1 } });

        expect(findTagsCount().text()).toMatchInterpolatedText('1 Tag');
      });
      it('with more than one tag in the image', () => {
        mountComponent({ item: { ...item, tagsCount: 3 } });

        expect(findTagsCount().text()).toMatchInterpolatedText('3 Tags');
      });
    });
  });
});
