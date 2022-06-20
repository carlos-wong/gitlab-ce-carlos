import { shallowMount } from '@vue/test-utils';

import SignInPage from '~/jira_connect/subscriptions/pages/sign_in.vue';
import SignInLegacyButton from '~/jira_connect/subscriptions/components/sign_in_legacy_button.vue';
import SignInOauthButton from '~/jira_connect/subscriptions/components/sign_in_oauth_button.vue';
import SubscriptionsList from '~/jira_connect/subscriptions/components/subscriptions_list.vue';
import createStore from '~/jira_connect/subscriptions/store';
import { I18N_DEFAULT_SIGN_IN_BUTTON_TEXT } from '~/jira_connect/subscriptions/constants';

jest.mock('~/jira_connect/subscriptions/utils');

const mockUsersPath = '/test';
const defaultProvide = {
  oauthMetadata: {},
  usersPath: mockUsersPath,
};

describe('SignInPage', () => {
  let wrapper;
  let store;

  const findSignInLegacyButton = () => wrapper.findComponent(SignInLegacyButton);
  const findSignInOauthButton = () => wrapper.findComponent(SignInOauthButton);
  const findSubscriptionsList = () => wrapper.findComponent(SubscriptionsList);

  const createComponent = ({ props, jiraConnectOauthEnabled } = {}) => {
    store = createStore();

    wrapper = shallowMount(SignInPage, {
      store,
      provide: {
        ...defaultProvide,
        glFeatures: {
          jiraConnectOauth: jiraConnectOauthEnabled,
        },
      },
      propsData: props,
      stubs: {
        SignInLegacyButton,
        SignInOauthButton,
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  describe('template', () => {
    describe.each`
      scenario                   | hasSubscriptions | signInButtonText
      ${'with subscriptions'}    | ${true}          | ${SignInPage.i18n.signInButtonTextWithSubscriptions}
      ${'without subscriptions'} | ${false}         | ${I18N_DEFAULT_SIGN_IN_BUTTON_TEXT}
    `('$scenario', ({ hasSubscriptions, signInButtonText }) => {
      describe('when `jiraConnectOauthEnabled` feature flag is disabled', () => {
        beforeEach(() => {
          createComponent({
            jiraConnectOauthEnabled: false,
            props: {
              hasSubscriptions,
            },
          });
        });

        it('renders legacy sign in button', () => {
          const button = findSignInLegacyButton();
          expect(button.props('usersPath')).toBe(mockUsersPath);
          expect(button.text()).toMatchInterpolatedText(signInButtonText);
        });
      });

      describe('when `jiraConnectOauthEnabled` feature flag is enabled', () => {
        beforeEach(() => {
          createComponent({
            jiraConnectOauthEnabled: true,
            props: {
              hasSubscriptions,
            },
          });
        });

        describe('oauth sign in button', () => {
          it('renders oauth sign in button', () => {
            const button = findSignInOauthButton();
            expect(button.text()).toMatchInterpolatedText(signInButtonText);
          });

          describe('when button emits `sign-in` event', () => {
            it('emits `sign-in-oauth` event', () => {
              const button = findSignInOauthButton();

              const mockUser = { name: 'test' };
              button.vm.$emit('sign-in', mockUser);

              expect(wrapper.emitted('sign-in-oauth')[0]).toEqual([mockUser]);
            });
          });

          describe('when button emits `error` event', () => {
            it('emits `error` event', () => {
              const button = findSignInOauthButton();
              button.vm.$emit('error');

              expect(wrapper.emitted('error')).toBeTruthy();
            });
          });
        });
      });

      it(`${hasSubscriptions ? 'renders' : 'does not render'} subscriptions list`, () => {
        createComponent({
          props: {
            hasSubscriptions,
          },
        });

        expect(findSubscriptionsList().exists()).toBe(hasSubscriptions);
      });
    });
  });
});
