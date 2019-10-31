import { mount } from '@vue/test-utils';
import projectEmptyState from '~/registry/components/project_empty_state.vue';

describe('Registry Project Empty state', () => {
  let wrapper;

  beforeEach(() => {
    wrapper = mount(projectEmptyState, {
      propsData: {
        noContainersImage: 'imageUrl',
        helpPagePath: 'help',
        repositoryUrl: 'url',
        twoFactorAuthHelpLink: 'help_link',
        personalAccessTokensHelpLink: 'personal_token',
        registryHostUrlWithPort: 'host',
      },
    });
  });

  afterEach(() => {
    wrapper.destroy();
  });

  it('to match the default snapshot', () => {
    expect(wrapper.element).toMatchSnapshot();
  });
});
