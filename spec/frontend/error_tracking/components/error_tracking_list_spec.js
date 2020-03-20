import { createLocalVue, mount } from '@vue/test-utils';
import Vuex from 'vuex';
import { GlEmptyState, GlLoadingIcon, GlFormInput, GlPagination } from '@gitlab/ui';
import stubChildren from 'helpers/stub_children';
import ErrorTrackingList from '~/error_tracking/components/error_tracking_list.vue';
import errorsList from './list_mock.json';

const localVue = createLocalVue();
localVue.use(Vuex);

describe('ErrorTrackingList', () => {
  let store;
  let wrapper;
  let actions;

  const findErrorListTable = () => wrapper.find('table');
  const findErrorListRows = () => wrapper.findAll('tbody tr');
  const findSortDropdown = () => wrapper.find('.sort-dropdown');
  const findRecentSearchesDropdown = () =>
    wrapper.find('.filtered-search-history-dropdown-wrapper');
  const findLoadingIcon = () => wrapper.find(GlLoadingIcon);
  const findPagination = () => wrapper.find(GlPagination);

  function mountComponent({
    errorTrackingEnabled = true,
    userCanEnableErrorTracking = true,
    stubs = {},
  } = {}) {
    wrapper = mount(ErrorTrackingList, {
      localVue,
      store,
      propsData: {
        indexPath: '/path',
        listPath: '/error_tracking',
        projectPath: 'project/test',
        enableErrorTrackingLink: '/link',
        userCanEnableErrorTracking,
        errorTrackingEnabled,
        illustrationPath: 'illustration/path',
      },
      stubs: {
        ...stubChildren(ErrorTrackingList),
        ...stubs,
      },
      data() {
        return { errorSearchQuery: 'search' };
      },
    });
  }

  beforeEach(() => {
    actions = {
      getErrorList: () => {},
      startPolling: jest.fn(),
      restartPolling: jest.fn().mockName('restartPolling'),
      addRecentSearch: jest.fn(),
      loadRecentSearches: jest.fn(),
      setIndexPath: jest.fn(),
      clearRecentSearches: jest.fn(),
      setEndpoint: jest.fn(),
      searchByQuery: jest.fn(),
      sortByField: jest.fn(),
      fetchPaginatedResults: jest.fn(),
      updateStatus: jest.fn(),
    };

    const state = {
      indexPath: '',
      recentSearches: [],
      errors: errorsList,
      loading: true,
      pagination: {
        previous: {
          cursor: 'previousCursor',
        },
        next: {
          cursor: 'nextCursor',
        },
      },
    };

    store = new Vuex.Store({
      modules: {
        list: {
          namespaced: true,
          actions,
          state,
        },
      },
    });
  });

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  describe('loading', () => {
    beforeEach(() => {
      store.state.list.loading = true;
      mountComponent();
    });

    it('shows spinner', () => {
      expect(findLoadingIcon().exists()).toBe(true);
      expect(findErrorListTable().exists()).toBe(false);
    });
  });

  describe('results', () => {
    beforeEach(() => {
      store.state.list.loading = false;
      store.state.list.errors = errorsList;
      mountComponent({
        stubs: {
          GlTable: false,
          GlDropdown: false,
          GlDropdownItem: false,
          GlLink: false,
        },
      });
    });

    it('shows table', () => {
      expect(findLoadingIcon().exists()).toBe(false);
      expect(findErrorListTable().exists()).toBe(true);
      expect(findSortDropdown().exists()).toBe(true);
    });

    it('shows list of errors in a table', () => {
      expect(findErrorListRows().length).toEqual(store.state.list.errors.length);
    });

    it('each error in a list should have a link to the error page', () => {
      const errorTitle = wrapper.findAll('tbody tr a');

      errorTitle.wrappers.forEach((_, index) => {
        expect(errorTitle.at(index).attributes('href')).toEqual(
          expect.stringMatching(/error_tracking\/\d+\/details$/),
        );
      });
    });

    it('each error in the list should have an ignore button', () => {
      findErrorListRows().wrappers.forEach(row => {
        expect(row.contains('glicon-stub[name="eye-slash"]')).toBe(true);
      });
    });

    it('each error in the list should have a resolve button', () => {
      findErrorListRows().wrappers.forEach(row => {
        expect(row.contains('glicon-stub[name="check-circle"]')).toBe(true);
      });
    });

    describe('filtering', () => {
      const findSearchBox = () => wrapper.find(GlFormInput);

      it('shows search box & sort dropdown', () => {
        expect(findSearchBox().exists()).toBe(true);
        expect(findSortDropdown().exists()).toBe(true);
      });

      it('it searches by query', () => {
        findSearchBox().trigger('keyup.enter');
        expect(actions.searchByQuery.mock.calls[0][1]).toEqual(wrapper.vm.errorSearchQuery);
      });

      it('it sorts by fields', () => {
        const findSortItem = () => wrapper.find('.dropdown-item');
        findSortItem().trigger('click');
        expect(actions.sortByField).toHaveBeenCalled();
      });
    });
  });

  describe('no results', () => {
    const findRefreshLink = () => wrapper.find('.js-try-again');

    beforeEach(() => {
      store.state.list.loading = false;
      store.state.list.errors = [];

      mountComponent({
        stubs: {
          GlTable: false,
          GlDropdown: false,
          GlDropdownItem: false,
        },
      });
    });

    it('shows empty table', () => {
      expect(findLoadingIcon().exists()).toBe(false);
      expect(findErrorListRows().length).toEqual(1);
      expect(findSortDropdown().exists()).toBe(true);
    });

    it('shows a message prompting to refresh', () => {
      expect(findRefreshLink().text()).toContain('Check again');
    });

    it('restarts polling', () => {
      findRefreshLink().vm.$emit('click');
      expect(actions.restartPolling).toHaveBeenCalled();
    });
  });

  describe('error tracking feature disabled', () => {
    beforeEach(() => {
      mountComponent({ errorTrackingEnabled: false });
    });

    it('shows empty state', () => {
      expect(wrapper.find(GlEmptyState).exists()).toBe(true);
      expect(findLoadingIcon().exists()).toBe(false);
      expect(findErrorListTable().exists()).toBe(false);
      expect(findSortDropdown().exists()).toBe(false);
    });
  });

  describe('When the ignore button on an error is clicked', () => {
    beforeEach(() => {
      store.state.list.loading = false;
      store.state.list.errors = errorsList;

      mountComponent({
        stubs: {
          GlTable: false,
          GlLink: false,
          GlButton: false,
        },
      });
    });

    it('sends the "ignored" status and error ID', () => {
      wrapper.find({ ref: 'ignoreError' }).trigger('click');
      expect(actions.updateStatus).toHaveBeenCalledWith(
        expect.anything(),
        {
          endpoint: '/project/test/-/error_tracking/3.json',
          redirectUrl: '/error_tracking',
          status: 'ignored',
        },
        undefined,
      );
    });
  });

  describe('When the resolve button on an error is clicked', () => {
    beforeEach(() => {
      store.state.list.loading = false;
      store.state.list.errors = errorsList;

      mountComponent({
        stubs: {
          GlTable: false,
          GlLink: false,
          GlButton: false,
        },
      });
    });

    it('sends "resolved" status and error ID', () => {
      wrapper.find({ ref: 'resolveError' }).trigger('click');
      expect(actions.updateStatus).toHaveBeenCalledWith(
        expect.anything(),
        {
          endpoint: '/project/test/-/error_tracking/3.json',
          redirectUrl: '/error_tracking',
          status: 'resolved',
        },
        undefined,
      );
    });
  });

  describe('When error tracking is disabled and user is not allowed to enable it', () => {
    beforeEach(() => {
      mountComponent({
        errorTrackingEnabled: false,
        userCanEnableErrorTracking: false,
        stubs: {
          GlLink: false,
          GlEmptyState: false,
        },
      });
    });

    it('shows empty state', () => {
      expect(wrapper.find('a').attributes('href')).toBe(
        '/help/user/project/operations/error_tracking.html',
      );
    });
  });

  describe('recent searches', () => {
    beforeEach(() => {
      mountComponent({
        stubs: {
          GlDropdown: false,
          GlDropdownItem: false,
        },
      });
    });

    it('shows empty message', () => {
      store.state.list.recentSearches = [];

      expect(findRecentSearchesDropdown().text()).toContain("You don't have any recent searches");
    });

    it('shows items', () => {
      store.state.list.recentSearches = ['great', 'search'];

      return wrapper.vm.$nextTick().then(() => {
        const dropdownItems = wrapper.findAll('.filtered-search-box li');
        expect(dropdownItems.length).toBe(3);
        expect(dropdownItems.at(0).text()).toBe('great');
        expect(dropdownItems.at(1).text()).toBe('search');
      });
    });

    describe('clear', () => {
      const clearRecentButton = () => wrapper.find({ ref: 'clearRecentSearches' });

      it('is hidden when list empty', () => {
        store.state.list.recentSearches = [];

        expect(clearRecentButton().exists()).toBe(false);
      });

      it('is visible when list has items', () => {
        store.state.list.recentSearches = ['some', 'searches'];

        return wrapper.vm.$nextTick().then(() => {
          expect(clearRecentButton().exists()).toBe(true);
          expect(clearRecentButton().text()).toBe('Clear recent searches');
        });
      });

      it('clears items on click', () => {
        store.state.list.recentSearches = ['some', 'searches'];

        return wrapper.vm.$nextTick().then(() => {
          clearRecentButton().vm.$emit('click');

          expect(actions.clearRecentSearches).toHaveBeenCalledTimes(1);
        });
      });
    });
  });

  describe('When pagination is not required', () => {
    beforeEach(() => {
      store.state.list.loading = false;
      store.state.list.pagination = {};
      mountComponent();
    });

    it('should not render the pagination component', () => {
      expect(findPagination().exists()).toBe(false);
    });
  });

  describe('When pagination is required', () => {
    describe('and the user is on the first page', () => {
      beforeEach(() => {
        store.state.list.loading = false;
        mountComponent({
          stubs: {
            GlPagination: false,
          },
        });
      });

      it('shows a disabled Prev button', () => {
        expect(wrapper.find('.prev-page-item').attributes('aria-disabled')).toBe('true');
      });
    });

    describe('and the user is not on the first page', () => {
      describe('and the previous button is clicked', () => {
        beforeEach(() => {
          store.state.list.loading = false;
          mountComponent({
            stubs: {
              GlTable: false,
              GlPagination: false,
            },
          });
          wrapper.setData({ pageValue: 2 });
          return wrapper.vm.$nextTick();
        });

        it('fetches the previous page of results', () => {
          expect(wrapper.find('.prev-page-item').attributes('aria-disabled')).toBe(undefined);
          wrapper.vm.goToPrevPage();
          expect(actions.fetchPaginatedResults).toHaveBeenCalled();
          expect(actions.fetchPaginatedResults).toHaveBeenLastCalledWith(
            expect.anything(),
            'previousCursor',
            undefined,
          );
        });
      });

      describe('and the next page button is clicked', () => {
        beforeEach(() => {
          store.state.list.loading = false;
          mountComponent();
        });

        it('fetches the next page of results', () => {
          window.scrollTo = jest.fn();
          findPagination().vm.$emit('input', 2);
          expect(window.scrollTo).toHaveBeenCalledWith(0, 0);
          expect(actions.fetchPaginatedResults).toHaveBeenCalled();
          expect(actions.fetchPaginatedResults).toHaveBeenLastCalledWith(
            expect.anything(),
            'nextCursor',
            undefined,
          );
        });
      });
    });
  });
});
