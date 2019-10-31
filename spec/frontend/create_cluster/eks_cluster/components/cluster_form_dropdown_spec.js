import { shallowMount } from '@vue/test-utils';

import ClusterFormDropdown from '~/create_cluster/eks_cluster/components/cluster_form_dropdown.vue';
import DropdownButton from '~/vue_shared/components/dropdown/dropdown_button.vue';
import DropdownSearchInput from '~/vue_shared/components/dropdown/dropdown_search_input.vue';
import DropdownHiddenInput from '~/vue_shared/components/dropdown/dropdown_hidden_input.vue';

describe('ClusterFormDropdown', () => {
  let vm;
  const firstItem = { name: 'item 1', value: 1 };
  const secondItem = { name: 'item 2', value: 2 };
  const items = [firstItem, secondItem, { name: 'item 3', value: 3 }];

  beforeEach(() => {
    vm = shallowMount(ClusterFormDropdown);
  });
  afterEach(() => vm.destroy());

  describe('when initial value is provided', () => {
    it('sets selectedItem to initial value', () => {
      vm.setProps({ items, value: secondItem.value });
      expect(vm.find(DropdownButton).props('toggleText')).toEqual(secondItem.name);
    });
  });

  describe('when no item is selected', () => {
    it('displays placeholder text', () => {
      const placeholder = 'placeholder';

      vm.setProps({ placeholder });

      expect(vm.find(DropdownButton).props('toggleText')).toEqual(placeholder);
    });
  });

  describe('when an item is selected', () => {
    beforeEach(() => {
      vm.setProps({ items });
      vm.findAll('.js-dropdown-item')
        .at(1)
        .trigger('click');
    });

    it('displays selected item label', () => {
      expect(vm.find(DropdownButton).props('toggleText')).toEqual(secondItem.name);
    });

    it('sets selected value to dropdown hidden input', () => {
      expect(vm.find(DropdownHiddenInput).props('value')).toEqual(secondItem.value);
    });
  });

  describe('when an item is selected and has a custom label property', () => {
    it('displays selected item custom label', () => {
      const labelProperty = 'customLabel';
      const selectedItem = { [labelProperty]: 'Name' };

      vm.setProps({ labelProperty });
      vm.setData({ selectedItem });

      expect(vm.find(DropdownButton).props('toggleText')).toEqual(selectedItem[labelProperty]);
    });
  });

  describe('when loading', () => {
    it('dropdown button isLoading', () => {
      vm.setProps({ loading: true });

      expect(vm.find(DropdownButton).props('isLoading')).toBe(true);
    });
  });

  describe('when loading and loadingText is provided', () => {
    it('uses loading text as toggle button text', () => {
      const loadingText = 'loading text';

      vm.setProps({ loading: true, loadingText });

      expect(vm.find(DropdownButton).props('toggleText')).toEqual(loadingText);
    });
  });

  describe('when disabled', () => {
    it('dropdown button isDisabled', () => {
      vm.setProps({ disabled: true });

      expect(vm.find(DropdownButton).props('isDisabled')).toBe(true);
    });
  });

  describe('when disabled and disabledText is provided', () => {
    it('uses disabled text as toggle button text', () => {
      const disabledText = 'disabled text';

      vm.setProps({ disabled: true, disabledText });

      expect(vm.find(DropdownButton).props('toggleText')).toBe(disabledText);
    });
  });

  describe('when has errors', () => {
    it('sets border-danger class selector to dropdown toggle', () => {
      vm.setProps({ hasErrors: true });

      expect(vm.find(DropdownButton).classes('border-danger')).toBe(true);
    });
  });

  describe('when has errors and an error message', () => {
    it('displays error message', () => {
      const errorMessage = 'error message';

      vm.setProps({ hasErrors: true, errorMessage });

      expect(vm.find('.js-eks-dropdown-error-message').text()).toEqual(errorMessage);
    });
  });

  describe('when no results are available', () => {
    it('displays empty text', () => {
      const emptyText = 'error message';

      vm.setProps({ items: [], emptyText });

      expect(vm.find('.js-empty-text').text()).toEqual(emptyText);
    });
  });

  it('displays search field placeholder', () => {
    const searchFieldPlaceholder = 'Placeholder';

    vm.setProps({ searchFieldPlaceholder });

    expect(vm.find(DropdownSearchInput).props('placeholderText')).toEqual(searchFieldPlaceholder);
  });

  it('it filters results by search query', () => {
    const searchQuery = secondItem.name;

    vm.setProps({ items });
    vm.setData({ searchQuery });

    expect(vm.findAll('.js-dropdown-item').length).toEqual(1);
    expect(vm.find('.js-dropdown-item').text()).toEqual(secondItem.name);
  });
});
