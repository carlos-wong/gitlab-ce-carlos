import { shallowMount } from '@vue/test-utils';
import IngressModsecuritySettings from '~/clusters/components/ingress_modsecurity_settings.vue';
import { APPLICATION_STATUS, INGRESS } from '~/clusters/constants';
import { GlAlert, GlToggle } from '@gitlab/ui';
import eventHub from '~/clusters/event_hub';

const { UPDATING } = APPLICATION_STATUS;

describe('IngressModsecuritySettings', () => {
  let wrapper;

  const defaultProps = {
    modsecurity_enabled: false,
    status: 'installable',
    installed: false,
  };

  const createComponent = (props = defaultProps) => {
    wrapper = shallowMount(IngressModsecuritySettings, {
      propsData: {
        ingress: {
          ...defaultProps,
          ...props,
        },
      },
    });
  };

  const findSaveButton = () => wrapper.find('.btn-success');
  const findCancelButton = () => wrapper.find('[variant="secondary"]');
  const findModSecurityToggle = () => wrapper.find(GlToggle);

  describe('when ingress is installed', () => {
    beforeEach(() => {
      createComponent({ installed: true, status: 'installed' });
      jest.spyOn(eventHub, '$emit');
    });

    it('does not render save and cancel buttons', () => {
      expect(findSaveButton().exists()).toBe(false);
      expect(findCancelButton().exists()).toBe(false);
    });

    describe('with toggle changed by the user', () => {
      beforeEach(() => {
        findModSecurityToggle().vm.$emit('change');
      });

      it('renders both save and cancel buttons', () => {
        expect(findSaveButton().exists()).toBe(true);
        expect(findCancelButton().exists()).toBe(true);
      });

      describe('and the save changes button is clicked', () => {
        beforeEach(() => {
          findSaveButton().vm.$emit('click');
        });

        it('triggers save event and pass current modsecurity value', () => {
          expect(eventHub.$emit).toHaveBeenCalledWith('updateApplication', {
            id: INGRESS,
            params: { modsecurity_enabled: false },
          });
        });
      });

      describe('and the cancel button is clicked', () => {
        beforeEach(() => {
          findCancelButton().vm.$emit('click');
        });

        it('triggers reset event and hides both cancel and save changes button', () => {
          expect(eventHub.$emit).toHaveBeenCalledWith('resetIngressModSecurityEnabled', INGRESS);
          expect(findSaveButton().exists()).toBe(false);
          expect(findCancelButton().exists()).toBe(false);
        });
      });
    });

    it('triggers set event to be propagated with the current modsecurity value', () => {
      wrapper.setData({ modSecurityEnabled: true });
      return wrapper.vm.$nextTick().then(() => {
        expect(eventHub.$emit).toHaveBeenCalledWith('setIngressModSecurityEnabled', {
          id: INGRESS,
          modSecurityEnabled: true,
        });
      });
    });

    describe(`when ingress status is ${UPDATING}`, () => {
      beforeEach(() => {
        createComponent({ installed: true, status: UPDATING });
      });

      it('renders loading spinner in save button', () => {
        expect(findSaveButton().props('loading')).toBe(true);
      });

      it('renders disabled save button', () => {
        expect(findSaveButton().props('disabled')).toBe(true);
      });

      it('renders save button with "Saving" label', () => {
        expect(findSaveButton().text()).toBe('Saving');
      });
    });

    describe('when ingress fails to update', () => {
      beforeEach(() => {
        createComponent({ updateFailed: true });
      });

      it('displays a error message', () => {
        expect(wrapper.find(GlAlert).exists()).toBe(true);
      });
    });
  });

  describe('when ingress is not installed', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not render the save button', () => {
      expect(findSaveButton().exists()).toBe(false);
      expect(findModSecurityToggle().props('value')).toBe(false);
    });
  });
});
