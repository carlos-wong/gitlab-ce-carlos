import { GlEmptyState, GlLoadingIcon, GlTable } from '@gitlab/ui';
import { mount, shallowMount } from '@vue/test-utils';
import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import PaginationBar from '~/vue_shared/components/pagination_bar/pagination_bar.vue';
import BulkImportsHistoryApp from '~/pages/import/bulk_imports/history/components/bulk_imports_history_app.vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';

describe('BulkImportsHistoryApp', () => {
  const API_URL = '/api/v4/bulk_imports/entities';

  const DEFAULT_HEADERS = {
    'x-page': 1,
    'x-per-page': 20,
    'x-next-page': 2,
    'x-total': 22,
    'x-total-pages': 2,
    'x-prev-page': null,
  };
  const DUMMY_RESPONSE = [
    {
      id: 1,
      bulk_import_id: 1,
      status: 'finished',
      source_full_path: 'top-level-group-12',
      destination_name: 'top-level-group-12',
      destination_namespace: 'h5bp',
      created_at: '2021-07-08T10:03:44.743Z',
      failures: [],
    },
    {
      id: 2,
      bulk_import_id: 2,
      status: 'failed',
      source_full_path: 'autodevops-demo',
      destination_name: 'autodevops-demo',
      destination_namespace: 'flightjs',
      parent_id: null,
      namespace_id: null,
      project_id: null,
      created_at: '2021-07-13T12:52:26.664Z',
      updated_at: '2021-07-13T13:34:49.403Z',
      failures: [
        {
          pipeline_class: 'BulkImports::Groups::Pipelines::GroupPipeline',
          pipeline_step: 'loader',
          exception_class: 'ActiveRecord::RecordNotUnique',
          correlation_id_value: '01FAFYSYZ7XPF3P9NSMTS693SZ',
          created_at: '2021-07-13T13:34:49.344Z',
        },
      ],
    },
  ];

  let wrapper;
  let mock;

  function createComponent({ shallow = true } = {}) {
    const mountFn = shallow ? shallowMount : mount;
    wrapper = mountFn(BulkImportsHistoryApp);
  }

  const originalApiVersion = gon.api_version;
  beforeAll(() => {
    gon.api_version = 'v4';
  });

  afterAll(() => {
    gon.api_version = originalApiVersion;
  });

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
    wrapper.destroy();
  });

  describe('general behavior', () => {
    it('renders loading state when loading', () => {
      createComponent();
      expect(wrapper.find(GlLoadingIcon).exists()).toBe(true);
    });

    it('renders empty state when no data is available', async () => {
      mock.onGet(API_URL).reply(200, [], DEFAULT_HEADERS);
      createComponent();
      await axios.waitForAll();

      expect(wrapper.find(GlLoadingIcon).exists()).toBe(false);
      expect(wrapper.find(GlEmptyState).exists()).toBe(true);
    });

    it('renders table with data when history is available', async () => {
      mock.onGet(API_URL).reply(200, DUMMY_RESPONSE, DEFAULT_HEADERS);
      createComponent();
      await axios.waitForAll();

      const table = wrapper.find(GlTable);
      expect(table.exists()).toBe(true);
      // can't use .props() or .attributes() here
      expect(table.vm.$attrs.items).toHaveLength(DUMMY_RESPONSE.length);
    });

    it('changes page when requested by pagination bar', async () => {
      const NEW_PAGE = 4;

      mock.onGet(API_URL).reply(200, DUMMY_RESPONSE, DEFAULT_HEADERS);
      createComponent();
      await axios.waitForAll();
      mock.resetHistory();

      wrapper.findComponent(PaginationBar).vm.$emit('set-page', NEW_PAGE);
      await axios.waitForAll();

      expect(mock.history.get.length).toBe(1);
      expect(mock.history.get[0].params).toStrictEqual(expect.objectContaining({ page: NEW_PAGE }));
    });
  });

  it('changes page size when requested by pagination bar', async () => {
    const NEW_PAGE_SIZE = 4;

    mock.onGet(API_URL).reply(200, DUMMY_RESPONSE, DEFAULT_HEADERS);
    createComponent();
    await axios.waitForAll();
    mock.resetHistory();

    wrapper.findComponent(PaginationBar).vm.$emit('set-page-size', NEW_PAGE_SIZE);
    await axios.waitForAll();

    expect(mock.history.get.length).toBe(1);
    expect(mock.history.get[0].params).toStrictEqual(
      expect.objectContaining({ per_page: NEW_PAGE_SIZE }),
    );
  });

  it('renders correct url for destination group when relative_url is empty', async () => {
    mock.onGet(API_URL).reply(200, DUMMY_RESPONSE, DEFAULT_HEADERS);
    createComponent({ shallow: false });
    await axios.waitForAll();

    expect(wrapper.find('tbody tr a').attributes().href).toBe(
      `/${DUMMY_RESPONSE[0].destination_namespace}/${DUMMY_RESPONSE[0].destination_name}`,
    );
  });

  describe('details button', () => {
    beforeEach(() => {
      mock.onGet(API_URL).reply(200, DUMMY_RESPONSE, DEFAULT_HEADERS);
      createComponent({ shallow: false });
      return axios.waitForAll();
    });

    it('renders details button if relevant item has failures', async () => {
      expect(
        extendedWrapper(wrapper.find('tbody').findAll('tr').at(1)).findByText('Details').exists(),
      ).toBe(true);
    });

    it('does not render details button if relevant item has no failures', () => {
      expect(
        extendedWrapper(wrapper.find('tbody').findAll('tr').at(0)).findByText('Details').exists(),
      ).toBe(false);
    });

    it('expands details when details button is clicked', async () => {
      const ORIGINAL_ROW_INDEX = 1;
      await extendedWrapper(wrapper.find('tbody').findAll('tr').at(ORIGINAL_ROW_INDEX))
        .findByText('Details')
        .trigger('click');

      const detailsRowContent = wrapper
        .find('tbody')
        .findAll('tr')
        .at(ORIGINAL_ROW_INDEX + 1)
        .find('pre');

      expect(detailsRowContent.exists()).toBe(true);
      expect(JSON.parse(detailsRowContent.text())).toStrictEqual(DUMMY_RESPONSE[1].failures);
    });
  });
});
