import { GlAlert } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { visitUrl } from '~/lib/utils/url_utility';
import WorkItemDetail from '~/work_items/components/work_item_detail.vue';
import WorkItemsRoot from '~/work_items/pages/work_item_root.vue';
import deleteWorkItem from '~/work_items/graphql/delete_work_item.mutation.graphql';
import { deleteWorkItemResponse, deleteWorkItemFailureResponse } from '../mock_data';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn(),
}));

Vue.use(VueApollo);

describe('Work items root component', () => {
  let wrapper;
  const issuesListPath = '/-/issues';
  const mockToastShow = jest.fn();

  const findWorkItemDetail = () => wrapper.findComponent(WorkItemDetail);
  const findAlert = () => wrapper.findComponent(GlAlert);

  const createComponent = ({
    deleteWorkItemHandler = jest.fn().mockResolvedValue(deleteWorkItemResponse),
  } = {}) => {
    wrapper = shallowMount(WorkItemsRoot, {
      apolloProvider: createMockApollo([[deleteWorkItem, deleteWorkItemHandler]]),
      provide: {
        issuesListPath,
      },
      propsData: {
        id: '1',
      },
      mocks: {
        $toast: {
          show: mockToastShow,
        },
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  it('renders WorkItemDetail', () => {
    createComponent();

    expect(findWorkItemDetail().props()).toEqual({
      isModal: false,
      workItemId: 'gid://gitlab/WorkItem/1',
      workItemParentId: null,
    });
  });

  it('deletes work item when deleteWorkItem event emitted', async () => {
    const deleteWorkItemHandler = jest.fn().mockResolvedValue(deleteWorkItemResponse);

    createComponent({
      deleteWorkItemHandler,
    });

    findWorkItemDetail().vm.$emit('deleteWorkItem');

    await waitForPromises();

    expect(deleteWorkItemHandler).toHaveBeenCalled();
    expect(mockToastShow).toHaveBeenCalled();
    expect(visitUrl).toHaveBeenCalledWith(issuesListPath);
  });

  it('shows alert if delete fails', async () => {
    const deleteWorkItemHandler = jest.fn().mockRejectedValue(deleteWorkItemFailureResponse);

    createComponent({
      deleteWorkItemHandler,
    });

    findWorkItemDetail().vm.$emit('deleteWorkItem');

    await waitForPromises();

    expect(findAlert().exists()).toBe(true);
  });
});
