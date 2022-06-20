import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createFlash from '~/flash';
import { IssuableType } from '~/issues/constants';
import SidebarEditableItem from '~/sidebar/components/sidebar_editable_item.vue';
import DropdownContents from '~/vue_shared/components/sidebar/labels_select_widget/dropdown_contents.vue';
import DropdownValue from '~/vue_shared/components/sidebar/labels_select_widget/dropdown_value.vue';
import issueLabelsQuery from '~/vue_shared/components/sidebar/labels_select_widget/graphql/issue_labels.query.graphql';
import updateIssueLabelsMutation from '~/boards/graphql/issue_set_labels.mutation.graphql';
import updateMergeRequestLabelsMutation from '~/sidebar/queries/update_merge_request_labels.mutation.graphql';
import issuableLabelsSubscription from 'ee_else_ce/sidebar/queries/issuable_labels.subscription.graphql';
import updateEpicLabelsMutation from '~/vue_shared/components/sidebar/labels_select_widget/graphql/epic_update_labels.mutation.graphql';
import LabelsSelectRoot from '~/vue_shared/components/sidebar/labels_select_widget/labels_select_root.vue';
import {
  mockConfig,
  issuableLabelsQueryResponse,
  updateLabelsMutationResponse,
  issuableLabelsSubscriptionResponse,
} from './mock_data';

jest.mock('~/flash');

Vue.use(VueApollo);

const successfulQueryHandler = jest.fn().mockResolvedValue(issuableLabelsQueryResponse);
const successfulMutationHandler = jest.fn().mockResolvedValue(updateLabelsMutationResponse);
const subscriptionHandler = jest.fn().mockResolvedValue(issuableLabelsSubscriptionResponse);
const errorQueryHandler = jest.fn().mockRejectedValue('Houston, we have a problem');

const updateLabelsMutation = {
  [IssuableType.Issue]: updateIssueLabelsMutation,
  [IssuableType.MergeRequest]: updateMergeRequestLabelsMutation,
  [IssuableType.Epic]: updateEpicLabelsMutation,
};

describe('LabelsSelectRoot', () => {
  let wrapper;

  const findSidebarEditableItem = () => wrapper.findComponent(SidebarEditableItem);
  const findDropdownValue = () => wrapper.findComponent(DropdownValue);
  const findDropdownContents = () => wrapper.findComponent(DropdownContents);

  const createComponent = ({
    config = mockConfig,
    slots = {},
    issuableType = IssuableType.Issue,
    queryHandler = successfulQueryHandler,
    mutationHandler = successfulMutationHandler,
    isRealtimeEnabled = false,
  } = {}) => {
    const mockApollo = createMockApollo([
      [issueLabelsQuery, queryHandler],
      [updateLabelsMutation[issuableType], mutationHandler],
      [issuableLabelsSubscription, subscriptionHandler],
    ]);

    wrapper = shallowMount(LabelsSelectRoot, {
      slots,
      apolloProvider: mockApollo,
      propsData: {
        ...config,
        issuableType,
        labelCreateType: 'project',
        workspaceType: 'project',
      },
      stubs: {
        SidebarEditableItem,
      },
      provide: {
        canUpdate: true,
        allowLabelEdit: true,
        allowLabelCreate: true,
        labelsManagePath: 'test',
        glFeatures: {
          realtimeLabels: isRealtimeEnabled,
        },
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  it('renders component with classes `labels-select-wrapper gl-relative`', () => {
    createComponent();
    expect(wrapper.classes()).toEqual(['labels-select-wrapper', 'gl-relative']);
  });

  it.each`
    variant         | cssClass
    ${'standalone'} | ${'is-standalone'}
    ${'embedded'}   | ${'is-embedded'}
  `(
    'renders component root element with CSS class `$cssClass` when `state.variant` is "$variant"',
    async ({ variant, cssClass }) => {
      createComponent({
        config: { ...mockConfig, variant },
      });

      await nextTick();
      expect(wrapper.classes()).toContain(cssClass);
    },
  );

  describe('if dropdown variant is `sidebar`', () => {
    it('renders sidebar editable item', () => {
      createComponent();
      expect(findSidebarEditableItem().exists()).toBe(true);
    });

    it('passes true `loading` prop to sidebar editable item when loading labels', () => {
      createComponent();
      expect(findSidebarEditableItem().props('loading')).toBe(true);
    });

    describe('when labels are fetched successfully', () => {
      beforeEach(async () => {
        createComponent();
        await waitForPromises();
      });

      it('passes true `loading` prop to sidebar editable item', () => {
        expect(findSidebarEditableItem().props('loading')).toBe(false);
      });

      it('renders dropdown value component when query labels is resolved', () => {
        expect(findDropdownValue().exists()).toBe(true);
        expect(findDropdownValue().props('selectedLabels')).toEqual([
          {
            color: '#330066',
            description: null,
            id: 'gid://gitlab/ProjectLabel/1',
            title: 'Label1',
            textColor: '#000000',
          },
        ]);
      });

      it('emits `onLabelRemove` event on dropdown value label remove event', () => {
        const label = { id: 'gid://gitlab/ProjectLabel/1' };
        findDropdownValue().vm.$emit('onLabelRemove', label);
        expect(wrapper.emitted('onLabelRemove')).toEqual([[label]]);
      });
    });

    it('creates flash with error message when query is rejected', async () => {
      createComponent({ queryHandler: errorQueryHandler });
      await waitForPromises();
      expect(createFlash).toHaveBeenCalledWith({ message: 'Error fetching labels.' });
    });
  });

  it('emits `updateSelectedLabels` event on dropdown contents `setLabels` event if iid is not set', async () => {
    const label = { id: 'gid://gitlab/ProjectLabel/1' };
    createComponent({ config: { ...mockConfig, iid: undefined } });

    findDropdownContents().vm.$emit('setLabels', [label]);
    expect(wrapper.emitted('updateSelectedLabels')).toEqual([[{ labels: [label] }]]);
  });

  describe.each`
    issuableType
    ${IssuableType.Issue}
    ${IssuableType.MergeRequest}
    ${IssuableType.Epic}
  `('when updating labels for $issuableType', ({ issuableType }) => {
    const label = { id: 'gid://gitlab/ProjectLabel/2' };

    it('sets the loading state', async () => {
      createComponent({ issuableType });
      await nextTick();
      findDropdownContents().vm.$emit('setLabels', [label]);
      await nextTick();

      expect(findSidebarEditableItem().props('loading')).toBe(true);
    });

    it('updates labels correctly after successful mutation', async () => {
      createComponent({ issuableType });
      await nextTick();
      findDropdownContents().vm.$emit('setLabels', [label]);
      await waitForPromises();

      expect(findDropdownValue().props('selectedLabels')).toEqual(
        updateLabelsMutationResponse.data.updateIssuableLabels.issuable.labels.nodes,
      );
    });

    it('displays an error if mutation was rejected', async () => {
      createComponent({ issuableType, mutationHandler: errorQueryHandler });
      await nextTick();
      findDropdownContents().vm.$emit('setLabels', [label]);
      await waitForPromises();

      expect(createFlash).toHaveBeenCalledWith({
        captureError: true,
        error: expect.anything(),
        message: 'An error occurred while updating labels.',
      });
    });

    it('does not emit `updateSelectedLabels` event when the subscription is triggered and FF is disabled', async () => {
      createComponent();
      await waitForPromises();

      expect(wrapper.emitted('updateSelectedLabels')).toBeUndefined();
    });

    it('emits `updateSelectedLabels` event when the subscription is triggered and FF is enabled', async () => {
      createComponent({ isRealtimeEnabled: true });
      await waitForPromises();

      expect(wrapper.emitted('updateSelectedLabels')).toEqual([
        [
          {
            id: '1',
            labels: issuableLabelsSubscriptionResponse.data.issuableLabelsUpdated.labels.nodes,
          },
        ],
      ]);
    });
  });
});
