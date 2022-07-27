import { GlAlert, GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import MockAdapter from 'axios-mock-adapter';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createFlash from '~/flash';
import httpStatus from '~/lib/utils/http_status';
import axios from '~/lib/utils/axios_utils';
import { STATUSES } from '~/import_entities/constants';
import { i18n, ROOT_NAMESPACE } from '~/import_entities/import_groups/constants';
import ImportTable from '~/import_entities/import_groups/components/import_table.vue';
import importGroupsMutation from '~/import_entities/import_groups/graphql/mutations/import_groups.mutation.graphql';
import PaginationLinks from '~/vue_shared/components/pagination_links.vue';

import { availableNamespacesFixture, generateFakeEntry } from '../graphql/fixtures';

jest.mock('~/flash');
jest.mock('~/import_entities/import_groups/services/status_poller');

Vue.use(VueApollo);

describe('import table', () => {
  let wrapper;
  let apolloProvider;
  let axiosMock;

  const SOURCE_URL = 'https://demo.host';
  const FAKE_GROUP = generateFakeEntry({ id: 1, status: STATUSES.NONE });
  const FAKE_GROUPS = [
    generateFakeEntry({ id: 1, status: STATUSES.NONE }),
    generateFakeEntry({ id: 2, status: STATUSES.FINISHED }),
  ];
  const FAKE_PAGE_INFO = { page: 1, perPage: 20, total: 40, totalPages: 2 };
  const FAKE_VERSION_VALIDATION = {
    features: {
      projectMigration: { available: false, minVersion: '14.8.0' },
      sourceInstanceVersion: '14.6.0',
    },
  };

  const findImportSelectedButton = () =>
    wrapper.findAll('button').wrappers.find((w) => w.text() === 'Import selected');
  const findImportButtons = () =>
    wrapper.findAll('button').wrappers.filter((w) => w.text() === 'Import');
  const findPaginationDropdown = () => wrapper.find('[data-testid="page-size"]');
  const findTargetNamespaceDropdown = (rowWrapper) =>
    rowWrapper.find('[data-testid="target-namespace-selector"]');
  const findPaginationDropdownText = () => findPaginationDropdown().find('button').text();
  const findSelectionCount = () => wrapper.find('[data-test-id="selection-count"]');

  const triggerSelectAllCheckbox = (checked = true) =>
    wrapper.find('thead input[type=checkbox]').setChecked(checked);

  const selectRow = (idx) =>
    wrapper.findAll('tbody td input[type=checkbox]').at(idx).setChecked(true);

  const createComponent = ({ bulkImportSourceGroups, importGroups, defaultTargetNamespace }) => {
    apolloProvider = createMockApollo([], {
      Query: {
        availableNamespaces: () => availableNamespacesFixture,
        bulkImportSourceGroups,
      },
      Mutation: {
        importGroups,
      },
    });

    wrapper = mount(ImportTable, {
      propsData: {
        groupPathRegex: /.*/,
        jobsPath: '/fake_job_path',
        sourceUrl: SOURCE_URL,
        historyPath: '/fake_history_path',
        defaultTargetNamespace,
      },
      apolloProvider,
    });
  };

  beforeAll(() => {
    gon.api_version = 'v4';
  });

  beforeEach(() => {
    axiosMock = new MockAdapter(axios);
    axiosMock.onGet(/.*\/exists$/, () => []).reply(200);
  });

  afterEach(() => {
    wrapper.destroy();
  });

  describe('loading state', () => {
    it('renders loading icon while performing request', async () => {
      createComponent({
        bulkImportSourceGroups: () => new Promise(() => {}),
      });
      await waitForPromises();

      expect(wrapper.find(GlLoadingIcon).exists()).toBe(true);
    });

    it('does not renders loading icon when request is completed', async () => {
      createComponent({
        bulkImportSourceGroups: () => [],
      });
      await waitForPromises();

      expect(wrapper.find(GlLoadingIcon).exists()).toBe(false);
    });
  });

  describe('empty state', () => {
    it('renders message about empty state when no groups are available for import', async () => {
      createComponent({
        bulkImportSourceGroups: () => ({
          nodes: [],
          pageInfo: FAKE_PAGE_INFO,
          versionValidation: FAKE_VERSION_VALIDATION,
        }),
      });
      await waitForPromises();

      expect(wrapper.find(GlEmptyState).props().title).toBe(i18n.NO_GROUPS_FOUND);
    });
  });

  it('renders import row for each group in response', async () => {
    createComponent({
      bulkImportSourceGroups: () => ({
        nodes: FAKE_GROUPS,
        pageInfo: FAKE_PAGE_INFO,
        versionValidation: FAKE_VERSION_VALIDATION,
      }),
    });
    await waitForPromises();

    expect(wrapper.findAll('tbody tr')).toHaveLength(FAKE_GROUPS.length);
  });

  it('correctly maintains root namespace as last import target', async () => {
    createComponent({
      bulkImportSourceGroups: () => ({
        nodes: [
          {
            ...generateFakeEntry({ id: 1, status: STATUSES.FINISHED }),
            lastImportTarget: {
              id: 1,
              targetNamespace: ROOT_NAMESPACE.fullPath,
              newName: 'does-not-matter',
            },
          },
        ],
        pageInfo: FAKE_PAGE_INFO,
        versionValidation: FAKE_VERSION_VALIDATION,
      }),
    });

    await waitForPromises();
    const firstRow = wrapper.find('tbody tr');
    const targetNamespaceDropdownButton = findTargetNamespaceDropdown(firstRow).find(
      '[aria-haspopup]',
    );
    expect(targetNamespaceDropdownButton.text()).toBe('No parent');
  });

  it('respects default namespace if provided', async () => {
    const targetNamespace = availableNamespacesFixture[1];

    createComponent({
      bulkImportSourceGroups: () => ({
        nodes: FAKE_GROUPS,
        pageInfo: FAKE_PAGE_INFO,
        versionValidation: FAKE_VERSION_VALIDATION,
      }),
      defaultTargetNamespace: targetNamespace.id,
    });

    await waitForPromises();

    const firstRow = wrapper.find('tbody tr');
    const targetNamespaceDropdownButton = findTargetNamespaceDropdown(firstRow).find(
      '[aria-haspopup]',
    );
    expect(targetNamespaceDropdownButton.text()).toBe(targetNamespace.fullPath);
  });

  it('does not render status string when result list is empty', async () => {
    createComponent({
      bulkImportSourceGroups: jest.fn().mockResolvedValue({
        nodes: [],
        pageInfo: FAKE_PAGE_INFO,
        versionValidation: FAKE_VERSION_VALIDATION,
      }),
    });
    await waitForPromises();

    expect(wrapper.text()).not.toContain('Showing 1-0');
  });

  it('invokes importGroups mutation when row button is clicked', async () => {
    createComponent({
      bulkImportSourceGroups: () => ({
        nodes: [FAKE_GROUP],
        pageInfo: FAKE_PAGE_INFO,
        versionValidation: FAKE_VERSION_VALIDATION,
      }),
    });

    jest.spyOn(apolloProvider.defaultClient, 'mutate');

    await waitForPromises();

    await findImportButtons()[0].trigger('click');
    expect(apolloProvider.defaultClient.mutate).toHaveBeenCalledWith({
      mutation: importGroupsMutation,
      variables: {
        importRequests: [
          {
            newName: FAKE_GROUP.lastImportTarget.newName,
            sourceGroupId: FAKE_GROUP.id,
            targetNamespace: availableNamespacesFixture[0].fullPath,
          },
        ],
      },
    });
  });

  it('displays error if importing group fails', async () => {
    createComponent({
      bulkImportSourceGroups: () => ({
        nodes: [FAKE_GROUP],
        pageInfo: FAKE_PAGE_INFO,
        versionValidation: FAKE_VERSION_VALIDATION,
      }),
      importGroups: () => {
        throw new Error();
      },
    });

    axiosMock.onPost('/import/bulk_imports.json').reply(httpStatus.BAD_REQUEST);

    await waitForPromises();
    await findImportButtons()[0].trigger('click');
    await waitForPromises();

    expect(createFlash).toHaveBeenCalledWith(
      expect.objectContaining({
        message: i18n.ERROR_IMPORT,
      }),
    );
  });

  describe('pagination', () => {
    const bulkImportSourceGroupsQueryMock = jest.fn().mockResolvedValue({
      nodes: [FAKE_GROUP],
      pageInfo: FAKE_PAGE_INFO,
      versionValidation: FAKE_VERSION_VALIDATION,
    });

    beforeEach(() => {
      createComponent({
        bulkImportSourceGroups: bulkImportSourceGroupsQueryMock,
      });
      return waitForPromises();
    });

    it('correctly passes pagination info from query', () => {
      expect(wrapper.find(PaginationLinks).props().pageInfo).toStrictEqual(FAKE_PAGE_INFO);
    });

    it('renders pagination dropdown', () => {
      expect(findPaginationDropdown().exists()).toBe(true);
    });

    it('updates page size when selected in Dropdown', async () => {
      const otherOption = findPaginationDropdown().findAll('li p').at(1);
      expect(otherOption.text()).toMatchInterpolatedText('50 items per page');

      bulkImportSourceGroupsQueryMock.mockResolvedValue({
        nodes: [FAKE_GROUP],
        pageInfo: { ...FAKE_PAGE_INFO, perPage: 50 },
        versionValidation: FAKE_VERSION_VALIDATION,
      });
      await otherOption.trigger('click');

      await waitForPromises();

      expect(findPaginationDropdownText()).toMatchInterpolatedText('50 items per page');
    });

    it('updates page when page change is requested', async () => {
      const REQUESTED_PAGE = 2;
      wrapper.find(PaginationLinks).props().change(REQUESTED_PAGE);

      await waitForPromises();
      expect(bulkImportSourceGroupsQueryMock).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({ page: REQUESTED_PAGE }),
        expect.anything(),
        expect.anything(),
      );
    });

    it('updates status text when page is changed', async () => {
      const REQUESTED_PAGE = 2;
      bulkImportSourceGroupsQueryMock.mockResolvedValue({
        nodes: [FAKE_GROUP],
        pageInfo: {
          page: 2,
          total: 38,
          perPage: 20,
          totalPages: 2,
        },
        versionValidation: FAKE_VERSION_VALIDATION,
      });
      wrapper.find(PaginationLinks).props().change(REQUESTED_PAGE);
      await waitForPromises();

      expect(wrapper.text()).toContain('Showing 21-21 of 38 groups that you own from');
    });
  });

  describe('filters', () => {
    const bulkImportSourceGroupsQueryMock = jest.fn().mockResolvedValue({
      nodes: [FAKE_GROUP],
      pageInfo: FAKE_PAGE_INFO,
      versionValidation: FAKE_VERSION_VALIDATION,
    });

    beforeEach(() => {
      createComponent({
        bulkImportSourceGroups: bulkImportSourceGroupsQueryMock,
      });
      return waitForPromises();
    });

    const setFilter = (value) => {
      const input = wrapper.find('input[placeholder="Filter by source group"]');
      input.setValue(value);
      return input.trigger('keydown.enter');
    };

    it('properly passes filter to graphql query when search box is submitted', async () => {
      createComponent({
        bulkImportSourceGroups: bulkImportSourceGroupsQueryMock,
      });
      await waitForPromises();

      const FILTER_VALUE = 'foo';
      await setFilter(FILTER_VALUE);
      await waitForPromises();

      expect(bulkImportSourceGroupsQueryMock).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({ filter: FILTER_VALUE }),
        expect.anything(),
        expect.anything(),
      );
    });

    it('updates status string when search box is submitted', async () => {
      createComponent({
        bulkImportSourceGroups: bulkImportSourceGroupsQueryMock,
      });
      await waitForPromises();

      const FILTER_VALUE = 'foo';
      await setFilter(FILTER_VALUE);
      await waitForPromises();

      expect(wrapper.text()).toContain(
        'Showing 1-1 of 40 groups that you own matching filter "foo" from',
      );
    });

    it('properly resets filter in graphql query when search box is cleared', async () => {
      const FILTER_VALUE = 'foo';
      await setFilter(FILTER_VALUE);
      await waitForPromises();

      bulkImportSourceGroupsQueryMock.mockClear();
      await apolloProvider.defaultClient.resetStore();

      await setFilter('');

      await waitForPromises();

      expect(bulkImportSourceGroupsQueryMock).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({ filter: '' }),
        expect.anything(),
        expect.anything(),
      );
    });
  });

  describe('bulk operations', () => {
    it('import all button correctly selects/deselects all groups', async () => {
      createComponent({
        bulkImportSourceGroups: () => ({
          nodes: FAKE_GROUPS,
          pageInfo: FAKE_PAGE_INFO,
          versionValidation: FAKE_VERSION_VALIDATION,
        }),
      });
      await waitForPromises();
      expect(findSelectionCount().text()).toMatchInterpolatedText('0 selected');
      await triggerSelectAllCheckbox();
      expect(findSelectionCount().text()).toMatchInterpolatedText('2 selected');
      await triggerSelectAllCheckbox(false);
      expect(findSelectionCount().text()).toMatchInterpolatedText('0 selected');
    });

    it('import selected button is disabled when no groups selected', async () => {
      createComponent({
        bulkImportSourceGroups: () => ({
          nodes: FAKE_GROUPS,
          pageInfo: FAKE_PAGE_INFO,
          versionValidation: FAKE_VERSION_VALIDATION,
        }),
      });
      await waitForPromises();

      expect(findImportSelectedButton().props().disabled).toBe(true);
    });

    it('import selected button is enabled when groups were selected for import', async () => {
      createComponent({
        bulkImportSourceGroups: () => ({
          nodes: FAKE_GROUPS,
          pageInfo: FAKE_PAGE_INFO,
          versionValidation: FAKE_VERSION_VALIDATION,
        }),
      });
      await waitForPromises();

      await selectRow(0);

      expect(findImportSelectedButton().props().disabled).toBe(false);
    });

    it('does not allow selecting already started groups', async () => {
      const NEW_GROUPS = [generateFakeEntry({ id: 1, status: STATUSES.STARTED })];

      createComponent({
        bulkImportSourceGroups: () => ({
          nodes: NEW_GROUPS,
          pageInfo: FAKE_PAGE_INFO,
          versionValidation: FAKE_VERSION_VALIDATION,
        }),
      });
      await waitForPromises();

      await selectRow(0);
      await nextTick();

      expect(findImportSelectedButton().props().disabled).toBe(true);
    });

    it('does not allow selecting groups with validation errors', async () => {
      const NEW_GROUPS = [
        generateFakeEntry({
          id: 2,
          status: STATUSES.NONE,
        }),
      ];

      createComponent({
        bulkImportSourceGroups: () => ({
          nodes: NEW_GROUPS,
          pageInfo: FAKE_PAGE_INFO,
          versionValidation: FAKE_VERSION_VALIDATION,
        }),
      });
      await waitForPromises();

      await wrapper.find('tbody input[aria-label="New name"]').setValue('');
      jest.runOnlyPendingTimers();
      await selectRow(0);
      await nextTick();

      expect(findImportSelectedButton().props().disabled).toBe(true);
    });

    it('invokes importGroups mutation when import selected button is clicked', async () => {
      const NEW_GROUPS = [
        generateFakeEntry({ id: 1, status: STATUSES.NONE }),
        generateFakeEntry({ id: 2, status: STATUSES.NONE }),
        generateFakeEntry({ id: 3, status: STATUSES.FINISHED }),
      ];

      createComponent({
        bulkImportSourceGroups: () => ({
          nodes: NEW_GROUPS,
          pageInfo: FAKE_PAGE_INFO,
          versionValidation: FAKE_VERSION_VALIDATION,
        }),
      });
      jest.spyOn(apolloProvider.defaultClient, 'mutate');
      await waitForPromises();

      await selectRow(0);
      await selectRow(1);
      await nextTick();

      await findImportSelectedButton().trigger('click');

      expect(apolloProvider.defaultClient.mutate).toHaveBeenCalledWith({
        mutation: importGroupsMutation,
        variables: {
          importRequests: [
            {
              targetNamespace: availableNamespacesFixture[0].fullPath,
              newName: NEW_GROUPS[0].lastImportTarget.newName,
              sourceGroupId: NEW_GROUPS[0].id,
            },
            {
              targetNamespace: availableNamespacesFixture[0].fullPath,
              newName: NEW_GROUPS[1].lastImportTarget.newName,
              sourceGroupId: NEW_GROUPS[1].id,
            },
          ],
        },
      });
    });
  });

  describe('unavailable features warning', () => {
    it('renders alert when there are unavailable features', async () => {
      createComponent({
        bulkImportSourceGroups: () => ({
          nodes: FAKE_GROUPS,
          pageInfo: FAKE_PAGE_INFO,
          versionValidation: FAKE_VERSION_VALIDATION,
        }),
      });
      await waitForPromises();

      expect(wrapper.find(GlAlert).exists()).toBe(true);
      expect(wrapper.find(GlAlert).text()).toContain('projects (require v14.8.0)');
    });

    it('does not renders alert when there are no unavailable features', async () => {
      createComponent({
        bulkImportSourceGroups: () => ({
          nodes: FAKE_GROUPS,
          pageInfo: FAKE_PAGE_INFO,
          versionValidation: {
            features: {
              projectMigration: { available: true, minVersion: '14.8.0' },
              sourceInstanceVersion: '14.6.0',
            },
          },
        }),
      });
      await waitForPromises();

      expect(wrapper.find(GlAlert).exists()).toBe(false);
    });
  });
});
