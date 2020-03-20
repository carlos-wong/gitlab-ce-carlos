import { shallowMount } from '@vue/test-utils';
import $ from 'jquery';

import { GlIcon } from '@gitlab/ui';
import ClusterFormDropdown from '~/create_cluster/components/cluster_form_dropdown.vue';
import DropdownButton from '~/vue_shared/components/dropdown/dropdown_button.vue';
import DropdownSearchInput from '~/vue_shared/components/dropdown/dropdown_search_input.vue';

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

      return vm.vm.$nextTick().then(() => {
        expect(vm.find(DropdownButton).props('toggleText')).toEqual(secondItem.name);
      });
    });
  });

  describe('when no item is selected', () => {
    it('displays placeholder text', () => {
      const placeholder = 'placeholder';

      vm.setProps({ placeholder });

      return vm.vm.$nextTick().then(() => {
        expect(vm.find(DropdownButton).props('toggleText')).toEqual(placeholder);
      });
    });
  });

  describe('when an item is selected', () => {
    beforeEach(() => {
      vm.setProps({ items });

      return vm.vm.$nextTick().then(() => {
        vm.findAll('.js-dropdown-item')
          .at(1)
          .trigger('click');
        return vm.vm.$nextTick();
      });
    });

    it('emits input event with selected item', () => {
      expect(vm.emitted('input')[0]).toEqual([secondItem.value]);
    });
  });

  describe('when multiple items are selected', () => {
    const value = [1];

    beforeEach(() => {
      vm.setProps({ items, multiple: true, value });
      return vm.vm
        .$nextTick()
        .then(() => {
          vm.findAll('.js-dropdown-item')
            .at(0)
            .trigger('click');
          return vm.vm.$nextTick();
        })
        .then(() => {
          vm.findAll('.js-dropdown-item')
            .at(1)
            .trigger('click');
          return vm.vm.$nextTick();
        });
    });

    it('emits input event with an array of selected items', () => {
      expect(vm.emitted('input')[1]).toEqual([[firstItem.value, secondItem.value]]);
    });
  });

  describe('when multiple items can be selected', () => {
    beforeEach(() => {
      vm.setProps({ items, multiple: true, value: firstItem.value });
      return vm.vm.$nextTick();
    });

    it('displays a checked GlIcon next to the item', () => {
      expect(vm.find(GlIcon).is('.invisible')).toBe(false);
      expect(vm.find(GlIcon).props('name')).toBe('mobile-issue-close');
    });
  });

  describe('when an item is selected and has a custom label property', () => {
    it('displays selected item custom label', () => {
      const labelProperty = 'customLabel';
      const label = 'Name';
      const currentValue = 1;
      const customLabelItems = [{ [labelProperty]: label, value: currentValue }];

      vm.setProps({ labelProperty, items: customLabelItems, value: currentValue });

      return vm.vm.$nextTick().then(() => {
        expect(vm.find(DropdownButton).props('toggleText')).toEqual(label);
      });
    });
  });

  describe('when loading', () => {
    it('dropdown button isLoading', () => {
      vm.setProps({ loading: true });

      return vm.vm.$nextTick().then(() => {
        expect(vm.find(DropdownButton).props('isLoading')).toBe(true);
      });
    });
  });

  describe('when loading and loadingText is provided', () => {
    it('uses loading text as toggle button text', () => {
      const loadingText = 'loading text';

      vm.setProps({ loading: true, loadingText });

      return vm.vm.$nextTick().then(() => {
        expect(vm.find(DropdownButton).props('toggleText')).toEqual(loadingText);
      });
    });
  });

  describe('when disabled', () => {
    it('dropdown button isDisabled', () => {
      vm.setProps({ disabled: true });

      return vm.vm.$nextTick().then(() => {
        expect(vm.find(DropdownButton).props('isDisabled')).toBe(true);
      });
    });
  });

  describe('when disabled and disabledText is provided', () => {
    it('uses disabled text as toggle button text', () => {
      const disabledText = 'disabled text';

      vm.setProps({ disabled: true, disabledText });

      return vm.vm.$nextTick().then(() => {
        expect(vm.find(DropdownButton).props('toggleText')).toBe(disabledText);
      });
    });
  });

  describe('when has errors', () => {
    it('sets border-danger class selector to dropdown toggle', () => {
      vm.setProps({ hasErrors: true });

      return vm.vm.$nextTick().then(() => {
        expect(vm.find(DropdownButton).classes('border-danger')).toBe(true);
      });
    });
  });

  describe('when has errors and an error message', () => {
    it('displays error message', () => {
      const errorMessage = 'error message';

      vm.setProps({ hasErrors: true, errorMessage });

      return vm.vm.$nextTick().then(() => {
        expect(vm.find('.js-eks-dropdown-error-message').text()).toEqual(errorMessage);
      });
    });
  });

  describe('when no results are available', () => {
    it('displays empty text', () => {
      const emptyText = 'error message';

      vm.setProps({ items: [], emptyText });

      return vm.vm.$nextTick().then(() => {
        expect(vm.find('.js-empty-text').text()).toEqual(emptyText);
      });
    });
  });

  it('displays search field placeholder', () => {
    const searchFieldPlaceholder = 'Placeholder';

    vm.setProps({ searchFieldPlaceholder });

    return vm.vm.$nextTick().then(() => {
      expect(vm.find(DropdownSearchInput).props('placeholderText')).toEqual(searchFieldPlaceholder);
    });
  });

  it('it filters results by search query', () => {
    const searchQuery = secondItem.name;

    vm.setProps({ items });
    vm.setData({ searchQuery });

    return vm.vm.$nextTick().then(() => {
      expect(vm.findAll('.js-dropdown-item').length).toEqual(1);
      expect(vm.find('.js-dropdown-item').text()).toEqual(secondItem.name);
    });
  });

  it('focuses dropdown search input when dropdown is displayed', () => {
    const dropdownEl = vm.find('.dropdown').element;

    expect(vm.find(DropdownSearchInput).props('focused')).toBe(false);

    $(dropdownEl).trigger('shown.bs.dropdown');

    return vm.vm.$nextTick(() => {
      expect(vm.find(DropdownSearchInput).props('focused')).toBe(true);
    });
  });
});
