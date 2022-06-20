import { GlSearchBoxByType } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { cloneDeep } from 'lodash';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import searchUsersQuery from '~/graphql_shared/queries/users_search.query.graphql';
import searchUsersQueryOnMR from '~/graphql_shared/queries/users_search_with_mr_permissions.graphql';
import { IssuableType } from '~/issues/constants';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import getIssueParticipantsQuery from '~/vue_shared/components/sidebar/queries/get_issue_participants.query.graphql';
import UserSelect from '~/vue_shared/components/user_select/user_select.vue';
import {
  searchResponse,
  searchResponseOnMR,
  projectMembersResponse,
  participantsQueryResponse,
} from 'jest/sidebar/mock_data';

const assignee = {
  id: 'gid://gitlab/User/4',
  avatarUrl:
    'https://www.gravatar.com/avatar/e64c7d89f26bd1972efa854d13d7dd61?s=80\u0026d=identicon',
  name: 'Developer',
  username: 'dev',
  webUrl: '/dev',
  status: null,
};

const mockError = jest.fn().mockRejectedValue('Error!');

const waitForSearch = async () => {
  jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  await nextTick();
  await waitForPromises();
};

Vue.use(VueApollo);

describe('User select dropdown', () => {
  let wrapper;
  let fakeApollo;

  const findSearchField = () => wrapper.findComponent(GlSearchBoxByType);
  const findParticipantsLoading = () => wrapper.find('[data-testid="loading-participants"]');
  const findSelectedParticipants = () => wrapper.findAll('[data-testid="selected-participant"]');
  const findUnselectedParticipants = () =>
    wrapper.findAll('[data-testid="unselected-participant"]');
  const findCurrentUser = () => wrapper.findAll('[data-testid="current-user"]');
  const findUnassignLink = () => wrapper.find('[data-testid="unassign"]');
  const findEmptySearchResults = () => wrapper.find('[data-testid="empty-results"]');

  const searchQueryHandlerSuccess = jest.fn().mockResolvedValue(projectMembersResponse);
  const participantsQueryHandlerSuccess = jest.fn().mockResolvedValue(participantsQueryResponse);

  const createComponent = ({
    props = {},
    searchQueryHandler = searchQueryHandlerSuccess,
    participantsQueryHandler = participantsQueryHandlerSuccess,
  } = {}) => {
    fakeApollo = createMockApollo([
      [searchUsersQuery, searchQueryHandler],
      [searchUsersQueryOnMR, jest.fn().mockResolvedValue(searchResponseOnMR)],
      [getIssueParticipantsQuery, participantsQueryHandler],
    ]);
    wrapper = shallowMount(UserSelect, {
      apolloProvider: fakeApollo,
      propsData: {
        headerText: 'test',
        text: 'test-text',
        fullPath: '/project',
        iid: '1',
        value: [],
        currentUser: {
          username: 'random',
          name: 'Mr. Random',
        },
        allowMultipleAssignees: false,
        ...props,
      },
      stubs: {
        GlDropdown: {
          template: `
            <div>
              <slot name="header"></slot>
              <slot></slot>
              <slot name="footer"></slot>
            </div>
          `,
          methods: {
            hide: jest.fn(),
          },
        },
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
    fakeApollo = null;
  });

  it('renders a loading spinner if participants are loading', () => {
    createComponent();

    expect(findParticipantsLoading().exists()).toBe(true);
  });

  it('skips the queries if `isEditing` prop is false', () => {
    createComponent({ props: { isEditing: false } });

    expect(findParticipantsLoading().exists()).toBe(false);
    expect(searchQueryHandlerSuccess).not.toHaveBeenCalled();
    expect(participantsQueryHandlerSuccess).not.toHaveBeenCalled();
  });

  it('emits an `error` event if participants query was rejected', async () => {
    createComponent({ participantsQueryHandler: mockError });
    await waitForPromises();

    expect(wrapper.emitted('error')).toEqual([[]]);
  });

  it('emits an `error` event if search query was rejected', async () => {
    createComponent({ searchQueryHandler: mockError });
    await waitForSearch();

    expect(wrapper.emitted('error')).toEqual([[]]);
  });

  it('renders current user if they are not in participants or assignees', async () => {
    createComponent();
    await waitForPromises();

    expect(findCurrentUser().exists()).toBe(true);
  });

  it('displays correct amount of selected users', async () => {
    createComponent({
      props: {
        value: [assignee],
      },
    });
    await waitForPromises();

    expect(findSelectedParticipants()).toHaveLength(1);
  });

  it('does not render a `Cannot merge` tooltip', async () => {
    createComponent();
    await waitForPromises();

    expect(findUnselectedParticipants().at(0).attributes('title')).toBe('');
  });

  describe('when search is empty', () => {
    it('renders a merged list of participants and project members', async () => {
      createComponent();
      await waitForPromises();

      expect(findUnselectedParticipants()).toHaveLength(4);
    });

    it('renders `Unassigned` link with the checkmark when there are no selected users', async () => {
      createComponent();
      await waitForPromises();
      expect(findUnassignLink().props('isChecked')).toBe(true);
    });

    it('renders `Unassigned` link without the checkmark when there are selected users', async () => {
      createComponent({
        props: {
          value: [assignee],
        },
      });
      await waitForPromises();
      expect(findUnassignLink().props('isChecked')).toBe(false);
    });

    it('emits an input event with empty array after clicking on `Unassigned`', async () => {
      createComponent({
        props: {
          value: [assignee],
        },
      });
      await waitForPromises();
      findUnassignLink().trigger('click');

      expect(wrapper.emitted('input')).toEqual([[[]]]);
    });

    it('emits an empty array after unselecting the only selected assignee', async () => {
      createComponent({
        props: {
          value: [assignee],
        },
      });
      await waitForPromises();

      findSelectedParticipants().at(0).trigger('click');
      expect(wrapper.emitted('input')).toEqual([[[]]]);
    });

    it('allows only one user to be selected if `allowMultipleAssignees` is false', async () => {
      createComponent({
        props: {
          value: [assignee],
        },
      });
      await waitForPromises();

      findUnselectedParticipants().at(0).trigger('click');

      expect(wrapper.emitted('input')).toMatchObject([
        [
          [
            {
              avatarUrl:
                'https://www.gravatar.com/avatar/e64c7d89f26bd1972efa854d13d7dd61?s=80&d=identicon',
              id: 'gid://gitlab/User/1',
              name: 'Administrator',
              status: null,
              username: 'root',
              webUrl: '/root',
            },
          ],
        ],
      ]);
    });

    it('adds user to selected if `allowMultipleAssignees` is true', async () => {
      createComponent({
        props: {
          value: [assignee],
          allowMultipleAssignees: true,
        },
      });
      await waitForPromises();

      findUnselectedParticipants().at(0).trigger('click');
      expect(wrapper.emitted('input')[0][0]).toHaveLength(2);
    });
  });

  describe('when searching', () => {
    it('does not show loading spinner when debounce timer is still running', async () => {
      createComponent();
      await waitForPromises();
      findSearchField().vm.$emit('input', 'roo');

      expect(findParticipantsLoading().exists()).toBe(false);
    });

    it('shows loading spinner when searching for users', async () => {
      createComponent();
      await waitForPromises();
      findSearchField().vm.$emit('input', 'roo');
      jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
      await nextTick();

      expect(findParticipantsLoading().exists()).toBe(true);
    });

    it('renders a list of found users and external participants matching search term', async () => {
      createComponent({ searchQueryHandler: jest.fn().mockResolvedValue(searchResponse) });
      await waitForPromises();

      findSearchField().vm.$emit('input', 'ro');
      await waitForSearch();

      expect(findUnselectedParticipants()).toHaveLength(3);
    });

    it('renders a list of found users only if no external participants match search term', async () => {
      createComponent({ searchQueryHandler: jest.fn().mockResolvedValue(searchResponse) });
      await waitForPromises();

      findSearchField().vm.$emit('input', 'roo');
      await waitForSearch();

      expect(findUnselectedParticipants()).toHaveLength(2);
    });

    it('shows a message about no matches if search returned an empty list', async () => {
      const responseCopy = cloneDeep(searchResponse);
      responseCopy.data.workspace.users.nodes = [];

      createComponent({
        searchQueryHandler: jest.fn().mockResolvedValue(responseCopy),
      });
      await waitForPromises();
      findSearchField().vm.$emit('input', 'tango');
      await waitForSearch();

      expect(findUnselectedParticipants()).toHaveLength(0);
      expect(findEmptySearchResults().exists()).toBe(true);
    });
  });

  describe('when on merge request sidebar', () => {
    beforeEach(() => {
      createComponent({ props: { issuableType: IssuableType.MergeRequest, issuableId: 1 } });
      return waitForPromises();
    });

    it('does not render a `Cannot merge` tooltip for a user that has merge permission', () => {
      expect(findUnselectedParticipants().at(0).attributes('title')).toBe('');
    });

    it('renders a `Cannot merge` tooltip for a user that does not have merge permission', () => {
      expect(findUnselectedParticipants().at(1).attributes('title')).toBe('Cannot merge');
    });
  });
});
