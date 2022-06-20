import { GlLoadingIcon } from '@gitlab/ui';
import { mount, shallowMount } from '@vue/test-utils';
import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import ImportErrorDetails from '~/pages/import/history/components/import_error_details.vue';

describe('ImportErrorDetails', () => {
  const FAKE_ID = 5;
  const API_URL = `/api/v4/projects/${FAKE_ID}`;

  let wrapper;
  let mock;

  function createComponent({ shallow = true } = {}) {
    const mountFn = shallow ? shallowMount : mount;
    wrapper = mountFn(ImportErrorDetails, {
      propsData: {
        id: FAKE_ID,
      },
    });
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

    it('renders import_error if it is available', async () => {
      const FAKE_IMPORT_ERROR = 'IMPORT ERROR';
      mock.onGet(API_URL).reply(200, { import_error: FAKE_IMPORT_ERROR });
      createComponent();
      await axios.waitForAll();

      expect(wrapper.find(GlLoadingIcon).exists()).toBe(false);
      expect(wrapper.find('pre').text()).toBe(FAKE_IMPORT_ERROR);
    });

    it('renders default text if error is not available', async () => {
      mock.onGet(API_URL).reply(200, { import_error: null });
      createComponent();
      await axios.waitForAll();

      expect(wrapper.find(GlLoadingIcon).exists()).toBe(false);
      expect(wrapper.find('pre').text()).toBe('No additional information provided.');
    });
  });
});
