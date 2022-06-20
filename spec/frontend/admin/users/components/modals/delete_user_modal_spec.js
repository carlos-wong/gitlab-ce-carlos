import { GlButton, GlFormInput, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import eventHub, {
  EVENT_OPEN_DELETE_USER_MODAL,
} from '~/admin/users/components/modals/delete_user_modal_event_hub';
import DeleteUserModal from '~/admin/users/components/modals/delete_user_modal.vue';
import UserDeletionObstaclesList from '~/vue_shared/components/user_deletion_obstacles/user_deletion_obstacles_list.vue';
import ModalStub from './stubs/modal_stub';

const TEST_DELETE_USER_URL = 'delete-url';
const TEST_BLOCK_USER_URL = 'block-url';
const TEST_CSRF = 'csrf';

describe('Delete user modal', () => {
  let wrapper;
  let formSubmitSpy;

  const findButton = (variant, category) =>
    wrapper
      .findAll(GlButton)
      .filter((w) => w.attributes('variant') === variant && w.attributes('category') === category)
      .at(0);
  const findForm = () => wrapper.find('form');
  const findUsernameInput = () => wrapper.findComponent(GlFormInput);
  const findPrimaryButton = () => findButton('danger', 'primary');
  const findSecondaryButton = () => findButton('danger', 'secondary');
  const findAuthenticityToken = () => new FormData(findForm().element).get('authenticity_token');
  const getUsername = () => findUsernameInput().attributes('value');
  const getMethodParam = () => new FormData(findForm().element).get('_method');
  const getFormAction = () => findForm().attributes('action');
  const findUserDeletionObstaclesList = () => wrapper.findComponent(UserDeletionObstaclesList);
  const findMessageUsername = () => wrapper.findByTestId('message-username');
  const findConfirmUsername = () => wrapper.findByTestId('confirm-username');

  const emitOpenModalEvent = (modalData) => {
    return eventHub.$emit(EVENT_OPEN_DELETE_USER_MODAL, modalData);
  };
  const setUsername = (username) => {
    return findUsernameInput().vm.$emit('input', username);
  };

  const username = 'username';
  const badUsername = 'bad_username';
  const userDeletionObstacles = ['schedule1', 'policy1'];

  const mockModalData = {
    username,
    blockPath: TEST_BLOCK_USER_URL,
    deletePath: TEST_DELETE_USER_URL,
    userDeletionObstacles,
    i18n: {
      title: 'Modal for %{username}',
      primaryButtonLabel: 'Delete user',
      messageBody: 'Delete %{username} or rather %{strongStart}block user%{strongEnd}?',
    },
  };

  const createComponent = (stubs = {}) => {
    wrapper = shallowMountExtended(DeleteUserModal, {
      propsData: {
        csrfToken: TEST_CSRF,
      },
      stubs: {
        GlModal: ModalStub,
        ...stubs,
      },
    });
  };

  beforeEach(() => {
    formSubmitSpy = jest.spyOn(HTMLFormElement.prototype, 'submit').mockImplementation();
  });

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
  });

  it('renders modal with form included', () => {
    createComponent();
    expect(findForm().element).toMatchSnapshot();
  });

  describe('on created', () => {
    beforeEach(() => {
      createComponent();
    });

    it('has disabled buttons', () => {
      expect(findPrimaryButton().attributes('disabled')).toBeTruthy();
      expect(findSecondaryButton().attributes('disabled')).toBeTruthy();
    });
  });

  describe('with incorrect username', () => {
    beforeEach(() => {
      createComponent();
      emitOpenModalEvent(mockModalData);

      return setUsername(badUsername);
    });

    it('shows incorrect username', () => {
      expect(getUsername()).toEqual(badUsername);
    });

    it('has disabled buttons', () => {
      expect(findPrimaryButton().attributes('disabled')).toBeTruthy();
      expect(findSecondaryButton().attributes('disabled')).toBeTruthy();
    });
  });

  describe('with correct username', () => {
    beforeEach(() => {
      createComponent();
      emitOpenModalEvent(mockModalData);

      return setUsername(username);
    });

    it('shows correct username', () => {
      expect(getUsername()).toEqual(username);
    });

    it('has enabled buttons', () => {
      expect(findPrimaryButton().attributes('disabled')).toBeFalsy();
      expect(findSecondaryButton().attributes('disabled')).toBeFalsy();
    });

    describe('when primary action is clicked', () => {
      beforeEach(() => {
        return findPrimaryButton().vm.$emit('click');
      });

      it('clears the input', () => {
        expect(getUsername()).toEqual('');
      });

      it('has correct form attributes and calls submit', () => {
        expect(getFormAction()).toBe(TEST_DELETE_USER_URL);
        expect(getMethodParam()).toBe('delete');
        expect(findAuthenticityToken()).toBe(TEST_CSRF);
        expect(formSubmitSpy).toHaveBeenCalled();
      });
    });

    describe('when secondary action is clicked', () => {
      beforeEach(() => {
        return findSecondaryButton().vm.$emit('click');
      });

      it('has correct form attributes and calls submit', () => {
        expect(getFormAction()).toBe(TEST_BLOCK_USER_URL);
        expect(getMethodParam()).toBe('put');
        expect(findAuthenticityToken()).toBe(TEST_CSRF);
        expect(formSubmitSpy).toHaveBeenCalled();
      });
    });
  });

  describe("when user's name has leading and trailing whitespace", () => {
    beforeEach(() => {
      createComponent({ GlSprintf });
      return emitOpenModalEvent({ ...mockModalData, username: ' John Smith ' });
    });

    it("displays user's name without whitespace", () => {
      expect(findMessageUsername().text()).toBe('John Smith');
      expect(findConfirmUsername().text()).toBe('John Smith');
    });

    it('passes user name without whitespace to the obstacles', () => {
      expect(findUserDeletionObstaclesList().props()).toMatchObject({
        userName: 'John Smith',
      });
    });

    it("shows enabled buttons when user's name is entered without whitespace", async () => {
      await setUsername('John Smith');

      expect(findPrimaryButton().attributes('disabled')).toBeUndefined();
      expect(findSecondaryButton().attributes('disabled')).toBeUndefined();
    });
  });

  describe('Related user-deletion-obstacles list', () => {
    it('does NOT render the list when user has no related obstacles', async () => {
      createComponent();
      await emitOpenModalEvent({ ...mockModalData, userDeletionObstacles: [] });

      expect(findUserDeletionObstaclesList().exists()).toBe(false);
    });

    it('renders the list when user has related obstalces', async () => {
      createComponent();
      await emitOpenModalEvent(mockModalData);

      const obstacles = findUserDeletionObstaclesList();
      expect(obstacles.exists()).toBe(true);
      expect(obstacles.props('obstacles')).toEqual(userDeletionObstacles);
    });
  });
});
