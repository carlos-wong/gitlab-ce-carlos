import { mount } from '@vue/test-utils';
import axios from '~/lib/utils/axios_utils';
import MockAdapter from 'axios-mock-adapter';
import EnvironmentsFolderViewComponent from '~/environments/folder/environments_folder_view.vue';
import EnvironmentTable from '~/environments/components/environments_table.vue';
import { environmentsList } from '../mock_data';
import { removeBreakLine, removeWhitespace } from 'helpers/text_helper';
import { GlPagination } from '@gitlab/ui';

describe('Environments Folder View', () => {
  let mock;
  let wrapper;

  const mockData = {
    endpoint: 'environments.json',
    folderName: 'review',
    canReadEnvironment: true,
    cssContainerClass: 'container',
    canaryDeploymentFeatureId: 'canary_deployment',
    showCanaryDeploymentCallout: true,
    userCalloutsPath: '/callouts',
    lockPromotionSvgPath: '/assets/illustrations/lock-promotion.svg',
    helpCanaryDeploymentsPath: 'help/canary-deployments',
  };

  const mockEnvironments = environmentList => {
    mock.onGet(mockData.endpoint).reply(
      200,
      {
        environments: environmentList,
        stopped_count: 1,
        available_count: 0,
      },
      {
        'X-nExt-pAge': '2',
        'x-page': '1',
        'X-Per-Page': '2',
        'X-Prev-Page': '',
        'X-TOTAL': '20',
        'X-Total-Pages': '10',
      },
    );
  };

  const createWrapper = () => {
    wrapper = mount(EnvironmentsFolderViewComponent, { propsData: mockData });
  };

  const findEnvironmentsTabAvailable = () => wrapper.find('.js-environments-tab-available');

  const findEnvironmentsTabStopped = () => wrapper.find('.js-environments-tab-stopped');

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
    wrapper.destroy();
  });

  describe('successful request', () => {
    beforeEach(() => {
      mockEnvironments(environmentsList);
      createWrapper();
      return axios.waitForAll();
    });

    it('should render a table with environments', () => {
      const table = wrapper.find(EnvironmentTable);

      expect(table.exists()).toBe(true);
      expect(table.find('.environment-name').text()).toEqual(environmentsList[0].name);
    });

    it('should render available tab with count', () => {
      const tabTable = findEnvironmentsTabAvailable();

      expect(tabTable.text()).toContain('Available');
      expect(tabTable.find('.badge').text()).toContain('0');
    });

    it('should render stopped tab with count', () => {
      const tabTable = findEnvironmentsTabStopped();

      expect(tabTable.text()).toContain('Stopped');
      expect(tabTable.find('.badge').text()).toContain('1');
    });

    it('should render parent folder name', () => {
      expect(removeBreakLine(removeWhitespace(wrapper.find('.js-folder-name').text()))).toContain(
        'Environments / review',
      );
    });

    describe('pagination', () => {
      it('should render pagination', () => {
        expect(wrapper.find(GlPagination).exists()).toBe(true);
      });

      it('should make an API request when changing page', () => {
        jest.spyOn(wrapper.vm, 'updateContent').mockImplementation(() => {});
        wrapper.find('.gl-pagination .page-item:nth-last-of-type(2) .page-link').trigger('click');
        expect(wrapper.vm.updateContent).toHaveBeenCalledWith({
          scope: wrapper.vm.scope,
          page: '10',
        });
      });

      it('should make an API request when using tabs', () => {
        jest.spyOn(wrapper.vm, 'updateContent').mockImplementation(() => {});
        findEnvironmentsTabStopped().trigger('click');
        expect(wrapper.vm.updateContent).toHaveBeenCalledWith({ scope: 'stopped', page: '1' });
      });
    });
  });

  describe('unsuccessfull request', () => {
    beforeEach(() => {
      mock.onGet(mockData.endpoint).reply(500, { environments: [] });
      createWrapper();
      return axios.waitForAll();
    });

    it('should not render a table', () => {
      expect(wrapper.find(EnvironmentTable).exists()).toBe(false);
    });

    it('should render available tab with count 0', () => {
      const tabTable = findEnvironmentsTabAvailable();

      expect(tabTable.text()).toContain('Available');
      expect(tabTable.find('.badge').text()).toContain('0');
    });

    it('should render stopped tab with count 0', () => {
      const tabTable = findEnvironmentsTabStopped();

      expect(tabTable.text()).toContain('Stopped');
      expect(tabTable.find('.badge').text()).toContain('0');
    });
  });

  describe('methods', () => {
    beforeEach(() => {
      mockEnvironments([]);
      createWrapper();
      jest.spyOn(window.history, 'pushState').mockImplementation(() => {});
      return axios.waitForAll();
    });

    describe('updateContent', () => {
      it('should set given parameters', () =>
        wrapper.vm.updateContent({ scope: 'stopped', page: '4' }).then(() => {
          expect(wrapper.vm.page).toEqual('4');
          expect(wrapper.vm.scope).toEqual('stopped');
          expect(wrapper.vm.requestData.page).toEqual('4');
        }));
    });

    describe('onChangeTab', () => {
      it('should set page to 1', () => {
        jest.spyOn(wrapper.vm, 'updateContent').mockImplementation(() => {});
        wrapper.vm.onChangeTab('stopped');
        expect(wrapper.vm.updateContent).toHaveBeenCalledWith({ scope: 'stopped', page: '1' });
      });
    });

    describe('onChangePage', () => {
      it('should update page and keep scope', () => {
        jest.spyOn(wrapper.vm, 'updateContent').mockImplementation(() => {});
        wrapper.vm.onChangePage(4);
        expect(wrapper.vm.updateContent).toHaveBeenCalledWith({
          scope: wrapper.vm.scope,
          page: '4',
        });
      });
    });
  });
});
