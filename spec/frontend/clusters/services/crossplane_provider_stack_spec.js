import { shallowMount } from '@vue/test-utils';
import { GlDropdownItem } from '@gitlab/ui';
import CrossplaneProviderStack from '~/clusters/components/crossplane_provider_stack.vue';

describe('CrossplaneProviderStack component', () => {
  let wrapper;

  const defaultProps = {
    stacks: [
      {
        name: 'Google Cloud Platform',
        code: 'gcp',
      },
      {
        name: 'Amazon Web Services',
        code: 'aws',
      },
    ],
  };

  function createComponent(props = {}) {
    const propsData = {
      ...defaultProps,
      ...props,
    };

    wrapper = shallowMount(CrossplaneProviderStack, {
      propsData,
    });
  }

  beforeEach(() => {
    const crossplane = {
      title: 'crossplane',
      stack: '',
    };
    createComponent({ crossplane });
  });

  const findDropdownElements = () => wrapper.findAll(GlDropdownItem);
  const findFirstDropdownElement = () => findDropdownElements().at(0);

  afterEach(() => {
    wrapper.destroy();
  });

  it('renders all of the available stacks in the dropdown', () => {
    const dropdownElements = findDropdownElements();

    expect(dropdownElements.length).toBe(defaultProps.stacks.length);

    defaultProps.stacks.forEach((stack, index) =>
      expect(dropdownElements.at(index).text()).toEqual(stack.name),
    );
  });

  it('displays the correct label for the first dropdown item if a stack is selected', () => {
    const crossplane = {
      title: 'crossplane',
      stack: 'gcp',
    };
    createComponent({ crossplane });
    expect(wrapper.vm.dropdownText).toBe('Google Cloud Platform');
  });

  it('emits the "set" event with the selected stack value', () => {
    const crossplane = {
      title: 'crossplane',
      stack: 'gcp',
    };
    createComponent({ crossplane });
    findFirstDropdownElement().vm.$emit('click');
    expect(wrapper.emitted().set[0][0].code).toEqual('gcp');
  });
  it('it renders the correct dropdown text when no stack is selected', () => {
    expect(wrapper.vm.dropdownText).toBe('Select Stack');
  });
});
