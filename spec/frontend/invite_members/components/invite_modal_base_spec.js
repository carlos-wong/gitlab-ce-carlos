import {
  GlDropdown,
  GlDropdownItem,
  GlDatepicker,
  GlFormGroup,
  GlSprintf,
  GlLink,
  GlModal,
} from '@gitlab/ui';
import { stubComponent } from 'helpers/stub_component';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import InviteModalBase from '~/invite_members/components/invite_modal_base.vue';
import ContentTransition from '~/vue_shared/components/content_transition.vue';
import { CANCEL_BUTTON_TEXT, INVITE_BUTTON_TEXT } from '~/invite_members/constants';
import { propsData } from '../mock_data/modal_base';

describe('InviteModalBase', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(InviteModalBase, {
      propsData: {
        ...propsData,
        ...props,
      },
      stubs: {
        ContentTransition,
        GlModal: stubComponent(GlModal, {
          template:
            '<div><slot name="modal-title"></slot><slot></slot><slot name="modal-footer"></slot></div>',
        }),
        GlDropdown: true,
        GlDropdownItem: true,
        GlSprintf,
        GlFormGroup: stubComponent(GlFormGroup, {
          props: ['state', 'invalidFeedback', 'description'],
        }),
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
  });

  const findDropdown = () => wrapper.findComponent(GlDropdown);
  const findDropdownItems = () => findDropdown().findAllComponents(GlDropdownItem);
  const findDatepicker = () => wrapper.findComponent(GlDatepicker);
  const findLink = () => wrapper.findComponent(GlLink);
  const findIntroText = () => wrapper.findByTestId('modal-base-intro-text').text();
  const findMembersFormGroup = () => wrapper.findByTestId('members-form-group');

  describe('rendering the modal', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the modal with the correct title', () => {
      expect(wrapper.findComponent(GlModal).props('title')).toBe(propsData.modalTitle);
    });

    it('displays the introText', () => {
      expect(findIntroText()).toBe(propsData.labelIntroText);
    });

    it('renders the Cancel button text correctly', () => {
      expect(wrapper.findComponent(GlModal).props('actionCancel')).toMatchObject({
        text: CANCEL_BUTTON_TEXT,
      });
    });

    it('renders the Invite button correctly', () => {
      expect(wrapper.findComponent(GlModal).props('actionPrimary')).toMatchObject({
        text: INVITE_BUTTON_TEXT,
        attributes: {
          variant: 'confirm',
          disabled: false,
          loading: false,
          'data-qa-selector': 'invite_button',
        },
      });
    });

    describe('rendering the access levels dropdown', () => {
      it('sets the default dropdown text to the default access level name', () => {
        expect(findDropdown().attributes('text')).toBe('Guest');
      });

      it('renders dropdown items for each accessLevel', () => {
        expect(findDropdownItems()).toHaveLength(5);
      });
    });

    describe('rendering the help link', () => {
      it('renders the correct link', () => {
        expect(findLink().attributes('href')).toBe(propsData.helpLink);
      });
    });

    describe('rendering the access expiration date field', () => {
      it('renders the datepicker', () => {
        expect(findDatepicker().exists()).toBe(true);
      });
    });

    it('renders the members form group', () => {
      expect(findMembersFormGroup().props()).toEqual({
        description: propsData.formGroupDescription,
        invalidFeedback: '',
        state: null,
      });
    });
  });

  it('with isLoading, shows loading for invite button', () => {
    createComponent({
      isLoading: true,
    });

    expect(wrapper.findComponent(GlModal).props('actionPrimary').attributes.loading).toBe(true);
  });

  it('with invalidFeedbackMessage, set members form group validation state', () => {
    createComponent({
      invalidFeedbackMessage: 'invalid message!',
    });

    expect(findMembersFormGroup().props()).toEqual({
      description: propsData.formGroupDescription,
      invalidFeedback: 'invalid message!',
      state: false,
    });
  });
});
