import {
  GlFilteredSearchSuggestion,
  GlFilteredSearchTokenSegment,
  GlDropdownDivider,
} from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createFlash from '~/flash';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { DEFAULT_NONE_ANY } from '~/vue_shared/components/filtered_search_bar/constants';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import CrmContactToken from '~/vue_shared/components/filtered_search_bar/tokens/crm_contact_token.vue';
import searchCrmContactsQuery from '~/vue_shared/components/filtered_search_bar/queries/search_crm_contacts.query.graphql';

import {
  mockCrmContacts,
  mockCrmContactToken,
  mockGroupCrmContactsQueryResponse,
  mockProjectCrmContactsQueryResponse,
} from '../mock_data';

jest.mock('~/flash');

const defaultStubs = {
  Portal: true,
  BaseToken,
  GlFilteredSearchSuggestionList: {
    template: '<div></div>',
    methods: {
      getValue: () => '=',
    },
  },
};

describe('CrmContactToken', () => {
  Vue.use(VueApollo);

  let wrapper;
  let fakeApollo;

  const getBaseToken = () => wrapper.findComponent(BaseToken);

  const searchGroupCrmContactsQueryHandler = jest
    .fn()
    .mockResolvedValue(mockGroupCrmContactsQueryResponse);
  const searchProjectCrmContactsQueryHandler = jest
    .fn()
    .mockResolvedValue(mockProjectCrmContactsQueryResponse);

  const mountComponent = ({
    config = mockCrmContactToken,
    value = { data: '' },
    active = false,
    stubs = defaultStubs,
    listeners = {},
    queryHandler = searchGroupCrmContactsQueryHandler,
  } = {}) => {
    fakeApollo = createMockApollo([[searchCrmContactsQuery, queryHandler]]);

    wrapper = mount(CrmContactToken, {
      propsData: {
        config,
        value,
        active,
        cursorPosition: 'start',
      },
      provide: {
        portalName: 'fake target',
        alignSuggestions: function fakeAlignSuggestions() {},
        suggestionsListClass: () => 'custom-class',
      },
      stubs,
      listeners,
      apolloProvider: fakeApollo,
    });
  };

  afterEach(() => {
    wrapper.destroy();
    fakeApollo = null;
  });

  describe('methods', () => {
    describe('fetchContacts', () => {
      describe('for groups', () => {
        beforeEach(() => {
          mountComponent();
        });

        it('calls the apollo query providing the searchString when search term is a string', async () => {
          getBaseToken().vm.$emit('fetch-suggestions', 'foo');
          await waitForPromises();

          expect(createFlash).not.toHaveBeenCalled();
          expect(searchGroupCrmContactsQueryHandler).toHaveBeenCalledWith({
            fullPath: 'group',
            isProject: false,
            searchString: 'foo',
            searchIds: null,
          });
          expect(getBaseToken().props('suggestions')).toEqual(mockCrmContacts);
        });

        it('calls the apollo query providing the searchId when search term is a number', async () => {
          getBaseToken().vm.$emit('fetch-suggestions', '5');
          await waitForPromises();

          expect(createFlash).not.toHaveBeenCalled();
          expect(searchGroupCrmContactsQueryHandler).toHaveBeenCalledWith({
            fullPath: 'group',
            isProject: false,
            searchString: null,
            searchIds: ['gid://gitlab/CustomerRelations::Contact/5'],
          });
          expect(getBaseToken().props('suggestions')).toEqual(mockCrmContacts);
        });
      });

      describe('for projects', () => {
        beforeEach(() => {
          mountComponent({
            config: {
              fullPath: 'project',
              isProject: true,
            },
            queryHandler: searchProjectCrmContactsQueryHandler,
          });
        });

        it('calls the apollo query providing the searchString when search term is a string', async () => {
          getBaseToken().vm.$emit('fetch-suggestions', 'foo');
          await waitForPromises();

          expect(createFlash).not.toHaveBeenCalled();
          expect(searchProjectCrmContactsQueryHandler).toHaveBeenCalledWith({
            fullPath: 'project',
            isProject: true,
            searchString: 'foo',
            searchIds: null,
          });
          expect(getBaseToken().props('suggestions')).toEqual(mockCrmContacts);
        });

        it('calls the apollo query providing the searchId when search term is a number', async () => {
          getBaseToken().vm.$emit('fetch-suggestions', '5');
          await waitForPromises();

          expect(createFlash).not.toHaveBeenCalled();
          expect(searchProjectCrmContactsQueryHandler).toHaveBeenCalledWith({
            fullPath: 'project',
            isProject: true,
            searchString: null,
            searchIds: ['gid://gitlab/CustomerRelations::Contact/5'],
          });
          expect(getBaseToken().props('suggestions')).toEqual(mockCrmContacts);
        });
      });

      it('calls `createFlash` with flash error message when request fails', async () => {
        mountComponent();

        jest.spyOn(wrapper.vm.$apollo, 'query').mockRejectedValue({});

        getBaseToken().vm.$emit('fetch-suggestions');
        await waitForPromises();

        expect(createFlash).toHaveBeenCalledWith({
          message: 'There was a problem fetching CRM contacts.',
        });
      });

      it('sets `loading` to false when request completes', async () => {
        mountComponent();

        jest.spyOn(wrapper.vm.$apollo, 'query').mockRejectedValue({});

        getBaseToken().vm.$emit('fetch-suggestions');

        await waitForPromises();

        expect(getBaseToken().props('suggestionsLoading')).toBe(false);
      });
    });
  });

  describe('template', () => {
    const defaultContacts = DEFAULT_NONE_ANY;

    it('renders base-token component', () => {
      mountComponent({
        config: { ...mockCrmContactToken, initialContacts: mockCrmContacts },
        value: { data: '1' },
      });

      const baseTokenEl = wrapper.find(BaseToken);

      expect(baseTokenEl.exists()).toBe(true);
      expect(baseTokenEl.props()).toMatchObject({
        suggestions: mockCrmContacts,
        getActiveTokenValue: wrapper.vm.getActiveContact,
      });
    });

    it.each(mockCrmContacts)('renders token item when value is selected', (contact) => {
      mountComponent({
        config: { ...mockCrmContactToken, initialContacts: mockCrmContacts },
        value: { data: `${getIdFromGraphQLId(contact.id)}` },
      });

      const tokenSegments = wrapper.findAll(GlFilteredSearchTokenSegment);

      expect(tokenSegments).toHaveLength(3); // Contact, =, Contact name
      expect(tokenSegments.at(2).text()).toBe(`${contact.firstName} ${contact.lastName}`); // Contact name
    });

    it('renders provided defaultContacts as suggestions', async () => {
      mountComponent({
        active: true,
        config: { ...mockCrmContactToken, defaultContacts },
        stubs: { Portal: true },
      });
      const tokenSegments = wrapper.findAll(GlFilteredSearchTokenSegment);
      const suggestionsSegment = tokenSegments.at(2);
      suggestionsSegment.vm.$emit('activate');
      await nextTick();

      const suggestions = wrapper.findAll(GlFilteredSearchSuggestion);

      expect(suggestions).toHaveLength(defaultContacts.length);
      defaultContacts.forEach((contact, index) => {
        expect(suggestions.at(index).text()).toBe(contact.text);
      });
    });

    it('does not render divider when no defaultContacts', async () => {
      mountComponent({
        active: true,
        config: { ...mockCrmContactToken, defaultContacts: [] },
        stubs: { Portal: true },
      });
      const tokenSegments = wrapper.findAll(GlFilteredSearchTokenSegment);
      const suggestionsSegment = tokenSegments.at(2);
      suggestionsSegment.vm.$emit('activate');
      await nextTick();

      expect(wrapper.find(GlFilteredSearchSuggestion).exists()).toBe(false);
      expect(wrapper.find(GlDropdownDivider).exists()).toBe(false);
    });

    it('renders `DEFAULT_NONE_ANY` as default suggestions', () => {
      mountComponent({
        active: true,
        config: { ...mockCrmContactToken },
        stubs: { Portal: true },
      });
      const tokenSegments = wrapper.findAll(GlFilteredSearchTokenSegment);
      const suggestionsSegment = tokenSegments.at(2);
      suggestionsSegment.vm.$emit('activate');

      const suggestions = wrapper.findAll(GlFilteredSearchSuggestion);

      expect(suggestions).toHaveLength(DEFAULT_NONE_ANY.length);
      DEFAULT_NONE_ANY.forEach((contact, index) => {
        expect(suggestions.at(index).text()).toBe(contact.text);
      });
    });

    it('emits listeners in the base-token', () => {
      const mockInput = jest.fn();
      mountComponent({
        listeners: {
          input: mockInput,
        },
      });
      wrapper.findComponent(BaseToken).vm.$emit('input', [{ data: 'mockData', operator: '=' }]);

      expect(mockInput).toHaveBeenLastCalledWith([{ data: 'mockData', operator: '=' }]);
    });
  });
});
