import Vue, { nextTick } from 'vue';
import { GlButton, GlLink, GlToast } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import setWindowLocation from 'helpers/set_window_location_helper';
import {
  extendedWrapper,
  shallowMountExtended,
  mountExtended,
} from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/flash';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { updateHistory } from '~/lib/utils/url_utility';

import RunnerTypeTabs from '~/runner/components/runner_type_tabs.vue';
import RunnerFilteredSearchBar from '~/runner/components/runner_filtered_search_bar.vue';
import RunnerList from '~/runner/components/runner_list.vue';
import RunnerStats from '~/runner/components/stat/runner_stats.vue';
import RunnerActionsCell from '~/runner/components/cells/runner_actions_cell.vue';
import RegistrationDropdown from '~/runner/components/registration/registration_dropdown.vue';
import RunnerPagination from '~/runner/components/runner_pagination.vue';

import {
  CREATED_ASC,
  CREATED_DESC,
  DEFAULT_SORT,
  INSTANCE_TYPE,
  GROUP_TYPE,
  PROJECT_TYPE,
  PARAM_KEY_PAUSED,
  PARAM_KEY_STATUS,
  STATUS_ONLINE,
  RUNNER_PAGE_SIZE,
  I18N_EDIT,
} from '~/runner/constants';
import getGroupRunnersQuery from '~/runner/graphql/list/group_runners.query.graphql';
import getGroupRunnersCountQuery from '~/runner/graphql/list/group_runners_count.query.graphql';
import GroupRunnersApp from '~/runner/group_runners/group_runners_app.vue';
import { captureException } from '~/runner/sentry_utils';
import FilteredSearch from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import {
  groupRunnersData,
  groupRunnersDataPaginated,
  groupRunnersCountData,
  onlineContactTimeoutSecs,
  staleTimeoutSecs,
} from '../mock_data';

Vue.use(VueApollo);
Vue.use(GlToast);

const mockGroupFullPath = 'group1';
const mockRegistrationToken = 'AABBCC';
const mockGroupRunnersEdges = groupRunnersData.data.group.runners.edges;
const mockGroupRunnersLimitedCount = mockGroupRunnersEdges.length;

jest.mock('~/flash');
jest.mock('~/runner/sentry_utils');
jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  updateHistory: jest.fn(),
}));

describe('GroupRunnersApp', () => {
  let wrapper;
  let mockGroupRunnersQuery;
  let mockGroupRunnersCountQuery;

  const findRunnerStats = () => wrapper.findComponent(RunnerStats);
  const findRunnerActionsCell = () => wrapper.findComponent(RunnerActionsCell);
  const findRegistrationDropdown = () => wrapper.findComponent(RegistrationDropdown);
  const findRunnerTypeTabs = () => wrapper.findComponent(RunnerTypeTabs);
  const findRunnerList = () => wrapper.findComponent(RunnerList);
  const findRunnerRow = (id) => extendedWrapper(wrapper.findByTestId(`runner-row-${id}`));
  const findRunnerPagination = () => extendedWrapper(wrapper.findComponent(RunnerPagination));
  const findRunnerPaginationNext = () => findRunnerPagination().findByLabelText('Go to next page');
  const findRunnerFilteredSearchBar = () => wrapper.findComponent(RunnerFilteredSearchBar);
  const findFilteredSearch = () => wrapper.findComponent(FilteredSearch);

  const mockCountQueryResult = (count) =>
    Promise.resolve({
      data: { group: { id: groupRunnersCountData.data.group.id, runners: { count } } },
    });

  const createComponent = ({ props = {}, mountFn = shallowMountExtended } = {}) => {
    const handlers = [
      [getGroupRunnersQuery, mockGroupRunnersQuery],
      [getGroupRunnersCountQuery, mockGroupRunnersCountQuery],
    ];

    wrapper = mountFn(GroupRunnersApp, {
      apolloProvider: createMockApollo(handlers),
      propsData: {
        registrationToken: mockRegistrationToken,
        groupFullPath: mockGroupFullPath,
        groupRunnersLimitedCount: mockGroupRunnersLimitedCount,
        ...props,
      },
      provide: {
        onlineContactTimeoutSecs,
        staleTimeoutSecs,
      },
    });
  };

  beforeEach(async () => {
    setWindowLocation(`/groups/${mockGroupFullPath}/-/runners`);

    mockGroupRunnersQuery = jest.fn().mockResolvedValue(groupRunnersData);
    mockGroupRunnersCountQuery = jest.fn().mockResolvedValue(groupRunnersCountData);

    createComponent();
    await waitForPromises();
  });

  it('shows total runner counts', async () => {
    createComponent({ mountFn: mountExtended });

    await waitForPromises();

    const stats = findRunnerStats().text();

    expect(stats).toMatch('Online runners 2');
    expect(stats).toMatch('Offline runners 2');
    expect(stats).toMatch('Stale runners 2');
  });

  it('shows the runner tabs with a runner count for each type', async () => {
    mockGroupRunnersCountQuery.mockImplementation(({ type }) => {
      switch (type) {
        case GROUP_TYPE:
          return mockCountQueryResult(2);
        case PROJECT_TYPE:
          return mockCountQueryResult(1);
        default:
          return mockCountQueryResult(4);
      }
    });

    createComponent({ mountFn: mountExtended });
    await waitForPromises();

    expect(findRunnerTypeTabs().text()).toMatchInterpolatedText('All 4 Group 2 Project 1');
  });

  it('shows the runner tabs with a formatted runner count', async () => {
    mockGroupRunnersCountQuery.mockImplementation(({ type }) => {
      switch (type) {
        case GROUP_TYPE:
          return mockCountQueryResult(2000);
        case PROJECT_TYPE:
          return mockCountQueryResult(1000);
        default:
          return mockCountQueryResult(3000);
      }
    });

    createComponent({ mountFn: mountExtended });
    await waitForPromises();

    expect(findRunnerTypeTabs().text()).toMatchInterpolatedText(
      'All 3,000 Group 2,000 Project 1,000',
    );
  });

  it('shows the runner setup instructions', () => {
    expect(findRegistrationDropdown().props('registrationToken')).toBe(mockRegistrationToken);
    expect(findRegistrationDropdown().props('type')).toBe(GROUP_TYPE);
  });

  it('shows the runners list', () => {
    const runners = findRunnerList().props('runners');
    expect(runners).toEqual(mockGroupRunnersEdges.map(({ node }) => node));
  });

  it('requests the runners with group path and no other filters', () => {
    expect(mockGroupRunnersQuery).toHaveBeenLastCalledWith({
      groupFullPath: mockGroupFullPath,
      status: undefined,
      type: undefined,
      sort: DEFAULT_SORT,
      first: RUNNER_PAGE_SIZE,
    });
  });

  it('sets tokens in the filtered search', () => {
    createComponent({ mountFn: mountExtended });

    const tokens = findFilteredSearch().props('tokens');

    expect(tokens).toEqual([
      expect.objectContaining({
        type: PARAM_KEY_PAUSED,
        options: expect.any(Array),
      }),
      expect.objectContaining({
        type: PARAM_KEY_STATUS,
        options: expect.any(Array),
      }),
    ]);
  });

  describe('Single runner row', () => {
    let showToast;

    const { webUrl, editUrl, node } = mockGroupRunnersEdges[0];
    const { id: graphqlId, shortSha } = node;
    const id = getIdFromGraphQLId(graphqlId);
    const COUNT_QUERIES = 6; // Smart queries that display a filtered count of runners
    const FILTERED_COUNT_QUERIES = 3; // Smart queries that display a count of runners in tabs

    beforeEach(async () => {
      mockGroupRunnersCountQuery.mockClear();

      createComponent({ mountFn: mountExtended });
      showToast = jest.spyOn(wrapper.vm.$root.$toast, 'show');

      await waitForPromises();
    });

    it('view link is displayed correctly', () => {
      const viewLink = findRunnerRow(id).findByTestId('td-summary').findComponent(GlLink);

      expect(viewLink.text()).toBe(`#${id} (${shortSha})`);
      expect(viewLink.attributes('href')).toBe(webUrl);
    });

    it('edit link is displayed correctly', () => {
      const editLink = findRunnerRow(id).findByTestId('td-actions').findComponent(GlButton);

      expect(editLink.attributes()).toMatchObject({
        'aria-label': I18N_EDIT,
        href: editUrl,
      });
    });

    it('When runner is paused or unpaused, some data is refetched', async () => {
      expect(mockGroupRunnersCountQuery).toHaveBeenCalledTimes(COUNT_QUERIES);

      findRunnerActionsCell().vm.$emit('toggledPaused');

      expect(mockGroupRunnersCountQuery).toHaveBeenCalledTimes(
        COUNT_QUERIES + FILTERED_COUNT_QUERIES,
      );

      expect(showToast).toHaveBeenCalledTimes(0);
    });

    it('When runner is deleted, data is refetched and a toast message is shown', async () => {
      findRunnerActionsCell().vm.$emit('deleted', { message: 'Runner deleted' });

      expect(showToast).toHaveBeenCalledTimes(1);
      expect(showToast).toHaveBeenCalledWith('Runner deleted');
    });
  });

  describe('when a filter is preselected', () => {
    beforeEach(async () => {
      setWindowLocation(`?status[]=${STATUS_ONLINE}&runner_type[]=${INSTANCE_TYPE}`);

      createComponent();
      await waitForPromises();
    });

    it('sets the filters in the search bar', () => {
      expect(findRunnerFilteredSearchBar().props('value')).toEqual({
        runnerType: INSTANCE_TYPE,
        filters: [{ type: 'status', value: { data: STATUS_ONLINE, operator: '=' } }],
        sort: 'CREATED_DESC',
        pagination: { page: 1 },
      });
    });

    it('requests the runners with filter parameters', () => {
      expect(mockGroupRunnersQuery).toHaveBeenLastCalledWith({
        groupFullPath: mockGroupFullPath,
        status: STATUS_ONLINE,
        type: INSTANCE_TYPE,
        sort: DEFAULT_SORT,
        first: RUNNER_PAGE_SIZE,
      });
    });
  });

  describe('when a filter is selected by the user', () => {
    beforeEach(async () => {
      findRunnerFilteredSearchBar().vm.$emit('input', {
        runnerType: null,
        filters: [{ type: PARAM_KEY_STATUS, value: { data: STATUS_ONLINE, operator: '=' } }],
        sort: CREATED_ASC,
      });

      await nextTick();
    });

    it('updates the browser url', () => {
      expect(updateHistory).toHaveBeenLastCalledWith({
        title: expect.any(String),
        url: 'http://test.host/groups/group1/-/runners?status[]=ONLINE&sort=CREATED_ASC',
      });
    });

    it('requests the runners with filters', () => {
      expect(mockGroupRunnersQuery).toHaveBeenLastCalledWith({
        groupFullPath: mockGroupFullPath,
        status: STATUS_ONLINE,
        sort: CREATED_ASC,
        first: RUNNER_PAGE_SIZE,
      });
    });
  });

  it('when runners have not loaded, shows a loading state', () => {
    createComponent();
    expect(findRunnerList().props('loading')).toBe(true);
  });

  describe('when no runners are found', () => {
    beforeEach(async () => {
      mockGroupRunnersQuery = jest.fn().mockResolvedValue({
        data: {
          group: {
            id: '1',
            runners: { nodes: [] },
          },
        },
      });
      createComponent();
      await waitForPromises();
    });

    it('shows a message for no results', async () => {
      expect(wrapper.text()).toContain('No runners found');
    });
  });

  describe('when runners query fails', () => {
    beforeEach(async () => {
      mockGroupRunnersQuery = jest.fn().mockRejectedValue(new Error('Error!'));
      createComponent();
      await waitForPromises();
    });

    it('error is shown to the user', async () => {
      expect(createAlert).toHaveBeenCalledTimes(1);
    });

    it('error is reported to sentry', async () => {
      expect(captureException).toHaveBeenCalledWith({
        error: new Error('Error!'),
        component: 'GroupRunnersApp',
      });
    });
  });

  describe('Pagination', () => {
    beforeEach(async () => {
      mockGroupRunnersQuery = jest.fn().mockResolvedValue(groupRunnersDataPaginated);

      createComponent({ mountFn: mountExtended });
      await waitForPromises();
    });

    it('navigates to the next page', async () => {
      await findRunnerPaginationNext().trigger('click');

      expect(mockGroupRunnersQuery).toHaveBeenLastCalledWith({
        groupFullPath: mockGroupFullPath,
        sort: CREATED_DESC,
        first: RUNNER_PAGE_SIZE,
        after: groupRunnersDataPaginated.data.group.runners.pageInfo.endCursor,
      });
    });
  });
});
