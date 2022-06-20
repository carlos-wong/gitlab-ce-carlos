import { GlFilteredSearchToken, GlFilteredSearchSuggestion, GlIcon } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { stubComponent } from 'helpers/stub_component';
import JobStatusToken from '~/jobs/components/filtered_search/tokens/job_status_token.vue';

describe('Job Status Token', () => {
  let wrapper;

  const findFilteredSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);
  const findAllFilteredSearchSuggestions = () =>
    wrapper.findAllComponents(GlFilteredSearchSuggestion);
  const findAllGlIcons = () => wrapper.findAllComponents(GlIcon);

  const defaultProps = {
    config: {
      type: 'status',
      icon: 'status',
      title: 'Status',
      unique: true,
    },
    value: {
      data: '',
    },
  };

  const createComponent = () => {
    wrapper = shallowMount(JobStatusToken, {
      propsData: {
        ...defaultProps,
      },
      stubs: {
        GlFilteredSearchToken: stubComponent(GlFilteredSearchToken, {
          template: `<div><slot name="suggestions"></slot></div>`,
        }),
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  afterEach(() => {
    wrapper.destroy();
  });

  it('passes config correctly', () => {
    expect(findFilteredSearchToken().props('config')).toEqual(defaultProps.config);
  });

  it('renders all job statuses available', () => {
    const expectedLength = 11;

    expect(findAllFilteredSearchSuggestions()).toHaveLength(expectedLength);
    expect(findAllGlIcons()).toHaveLength(expectedLength);
  });
});
