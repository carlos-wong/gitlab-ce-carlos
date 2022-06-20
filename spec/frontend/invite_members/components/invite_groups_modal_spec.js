import { GlModal, GlSprintf } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import Api from '~/api';
import InviteGroupsModal from '~/invite_members/components/invite_groups_modal.vue';
import InviteModalBase from '~/invite_members/components/invite_modal_base.vue';
import ContentTransition from '~/vue_shared/components/content_transition.vue';
import GroupSelect from '~/invite_members/components/group_select.vue';
import { stubComponent } from 'helpers/stub_component';
import { propsData, sharedGroup } from '../mock_data/group_modal';

describe('InviteGroupsModal', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(InviteGroupsModal, {
      propsData: {
        ...propsData,
        ...props,
      },
      stubs: {
        InviteModalBase,
        ContentTransition,
        GlSprintf,
        GlModal: stubComponent(GlModal, {
          template: '<div><slot></slot><slot name="modal-footer"></slot></div>',
        }),
      },
    });
  };

  const createInviteGroupToProjectWrapper = () => {
    createComponent({ isProject: true });
  };

  const createInviteGroupToGroupWrapper = () => {
    createComponent({ isProject: false });
  };

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
  });

  const findModal = () => wrapper.findComponent(GlModal);
  const findGroupSelect = () => wrapper.findComponent(GroupSelect);
  const findIntroText = () => wrapper.findByTestId('modal-base-intro-text').text();
  const findMembersFormGroup = () => wrapper.findByTestId('members-form-group');
  const membersFormGroupInvalidFeedback = () =>
    findMembersFormGroup().attributes('invalid-feedback');
  const findBase = () => wrapper.findComponent(InviteModalBase);
  const triggerGroupSelect = (val) => findGroupSelect().vm.$emit('input', val);
  const emitEventFromModal = (eventName) => () =>
    findModal().vm.$emit(eventName, { preventDefault: jest.fn() });
  const hideModal = emitEventFromModal('hidden');
  const clickInviteButton = emitEventFromModal('primary');
  const clickCancelButton = emitEventFromModal('cancel');

  describe('displaying the correct introText and form group description', () => {
    describe('when inviting to a project', () => {
      it('includes the correct type, and formatted intro text', () => {
        createInviteGroupToProjectWrapper();

        expect(findIntroText()).toBe("You're inviting a group to the test name project.");
      });
    });

    describe('when inviting to a group', () => {
      it('includes the correct type, and formatted intro text', () => {
        createInviteGroupToGroupWrapper();

        expect(findIntroText()).toBe("You're inviting a group to the test name group.");
      });
    });
  });

  describe('submitting the invite form', () => {
    let apiResolve;
    let apiReject;
    const groupPostData = {
      group_id: sharedGroup.id,
      group_access: propsData.defaultAccessLevel,
      expires_at: undefined,
      format: 'json',
    };

    beforeEach(() => {
      createComponent();
      triggerGroupSelect(sharedGroup);

      wrapper.vm.$toast = { show: jest.fn() };
      jest.spyOn(Api, 'groupShareWithGroup').mockImplementation(
        () =>
          new Promise((resolve, reject) => {
            apiResolve = resolve;
            apiReject = reject;
          }),
      );

      clickInviteButton();
    });

    it('shows loading', () => {
      expect(findBase().props('isLoading')).toBe(true);
    });

    it('calls Api groupShareWithGroup with the correct params', () => {
      expect(Api.groupShareWithGroup).toHaveBeenCalledWith(propsData.id, groupPostData);
    });

    describe('when succeeds', () => {
      beforeEach(() => {
        apiResolve({ data: groupPostData });
      });

      it('hides loading', () => {
        expect(findBase().props('isLoading')).toBe(false);
      });

      it('has no error message', () => {
        expect(findBase().props('invalidFeedbackMessage')).toBe('');
      });

      it('displays the successful toastMessage', () => {
        expect(wrapper.vm.$toast.show).toHaveBeenCalledWith('Members were successfully added', {
          onComplete: expect.any(Function),
        });
      });
    });

    describe('when fails', () => {
      beforeEach(() => {
        apiReject({ response: { data: { success: false } } });
      });

      it('does not show the toast message on failure', () => {
        expect(wrapper.vm.$toast.show).not.toHaveBeenCalled();
      });

      it('displays the generic error for http server error', () => {
        expect(membersFormGroupInvalidFeedback()).toBe('Something went wrong');
      });

      it.each`
        desc                                   | act
        ${'when the cancel button is clicked'} | ${clickCancelButton}
        ${'when the modal is hidden'}          | ${hideModal}
        ${'when invite button is clicked'}     | ${clickInviteButton}
        ${'when group input changes'}          | ${() => triggerGroupSelect(sharedGroup)}
      `('clears the error, $desc', async ({ act }) => {
        act();

        await nextTick();

        expect(membersFormGroupInvalidFeedback()).toBe('');
      });
    });
  });
});
