import $ from 'jquery';
import { parseBoolean } from '../lib/utils/common_utils';
import { s__ } from '../locale';
import setupToggleButtons from '../toggle_buttons';
import CreateItemDropdown from '../create_item_dropdown';
import SecretValues from '../behaviors/secret_values';

const ALL_ENVIRONMENTS_STRING = s__('CiVariable|All environments');

function createEnvironmentItem(value) {
  return {
    title: value === '*' ? ALL_ENVIRONMENTS_STRING : value,
    id: value,
    text: value === '*' ? s__('CiVariable|* (All environments)') : value,
  };
}

export default class VariableList {
  constructor({ container, formField, maskableRegex }) {
    this.$container = $(container);
    this.formField = formField;
    this.maskableRegex = new RegExp(maskableRegex);
    this.environmentDropdownMap = new WeakMap();

    this.inputMap = {
      id: {
        selector: '.js-ci-variable-input-id',
        default: '',
      },
      variable_type: {
        selector: '.js-ci-variable-input-variable-type',
        default: 'env_var',
      },
      key: {
        selector: '.js-ci-variable-input-key',
        default: '',
      },
      secret_value: {
        selector: '.js-ci-variable-input-value',
        default: '',
      },
      protected: {
        selector: '.js-ci-variable-input-protected',
        // use `attr` instead of `data` as we don't want the value to be
        // converted. we need the value as a string.
        default: $('.js-ci-variable-input-protected').attr('data-default'),
      },
      masked: {
        selector: '.js-ci-variable-input-masked',
        // use `attr` instead of `data` as we don't want the value to be
        // converted. we need the value as a string.
        default: $('.js-ci-variable-input-masked').attr('data-default'),
      },
      environment_scope: {
        // We can't use a `.js-` class here because
        // gl_dropdown replaces the <input> and doesn't copy over the class
        // See https://gitlab.com/gitlab-org/gitlab-foss/issues/42458
        selector: `input[name="${this.formField}[variables_attributes][][environment_scope]"]`,
        default: '*',
      },
      _destroy: {
        selector: '.js-ci-variable-input-destroy',
        default: '',
      },
    };

    this.secretValues = new SecretValues({
      container: this.$container[0],
      valueSelector: '.js-row:not(:last-child) .js-secret-value',
      placeholderSelector: '.js-row:not(:last-child) .js-secret-value-placeholder',
    });
  }

  init() {
    this.bindEvents();
    this.secretValues.init();
  }

  bindEvents() {
    this.$container.find('.js-row').each((index, rowEl) => {
      this.initRow(rowEl);
    });

    this.$container.on('click', '.js-row-remove-button', e => {
      e.preventDefault();
      this.removeRow($(e.currentTarget).closest('.js-row'));
    });

    const inputSelector = Object.keys(this.inputMap)
      .map(name => this.inputMap[name].selector)
      .join(',');

    // Remove any empty rows except the last row
    this.$container.on('blur', inputSelector, e => {
      const $row = $(e.currentTarget).closest('.js-row');

      if ($row.is(':not(:last-child)') && !this.checkIfRowTouched($row)) {
        this.removeRow($row);
      }
    });

    this.$container.on('input trigger-change', inputSelector, e => {
      // Always make sure there is an empty last row
      const $lastRow = this.$container.find('.js-row').last();

      if (this.checkIfRowTouched($lastRow)) {
        this.insertRow($lastRow);
      }

      // If masked, validate value against regex
      this.validateMaskability($(e.currentTarget).closest('.js-row'));
    });
  }

  initRow(rowEl) {
    const $row = $(rowEl);

    setupToggleButtons($row[0]);

    // Reset the resizable textarea
    $row.find(this.inputMap.secret_value.selector).css('height', '');

    const $environmentSelect = $row.find('.js-variable-environment-toggle');
    if ($environmentSelect.length) {
      const createItemDropdown = new CreateItemDropdown({
        $dropdown: $environmentSelect,
        defaultToggleLabel: ALL_ENVIRONMENTS_STRING,
        fieldName: `${this.formField}[variables_attributes][][environment_scope]`,
        getData: (term, callback) => callback(this.getEnvironmentValues()),
        createNewItemFromValue: createEnvironmentItem,
        onSelect: () => {
          // Refresh the other dropdowns in the variable list
          // so they have the new value we just picked
          this.refreshDropdownData();

          $row.find(this.inputMap.environment_scope.selector).trigger('trigger-change');
        },
      });

      // Clear out any data that might have been left-over from the row clone
      createItemDropdown.clearDropdown();

      this.environmentDropdownMap.set($row[0], createItemDropdown);
    }
  }

  insertRow($row) {
    const $rowClone = $row.clone();
    $rowClone.removeAttr('data-is-persisted');

    // Reset the inputs to their defaults
    Object.keys(this.inputMap).forEach(name => {
      const entry = this.inputMap[name];
      $rowClone.find(entry.selector).val(entry.default);
    });

    // Close any dropdowns
    $rowClone.find('.dropdown-menu.show').each((index, $dropdown) => {
      $dropdown.classList.remove('show');
    });

    this.initRow($rowClone);

    $row.after($rowClone);
  }

  removeRow(row) {
    const $row = $(row);
    const isPersisted = parseBoolean($row.attr('data-is-persisted'));

    if (isPersisted) {
      $row.hide();
      $row
        // eslint-disable-next-line no-underscore-dangle
        .find(this.inputMap._destroy.selector)
        .val(true);
    } else {
      $row.remove();
    }

    // Refresh the other dropdowns in the variable list
    // so any value with the variable deleted is gone
    this.refreshDropdownData();
  }

  checkIfRowTouched($row) {
    return Object.keys(this.inputMap).some(name => {
      // Row should not qualify as touched if only switches have been touched
      if (['protected', 'masked'].includes(name)) return false;

      const entry = this.inputMap[name];
      const $el = $row.find(entry.selector);
      return $el.length && $el.val() !== entry.default;
    });
  }

  validateMaskability($row) {
    const invalidInputClass = 'gl-field-error-outline';

    const variableValue = $row.find(this.inputMap.secret_value.selector).val();
    const isValueMaskable = this.maskableRegex.test(variableValue) || variableValue === '';
    const isMaskedChecked = $row.find(this.inputMap.masked.selector).val() === 'true';

    // Show a validation error if the user wants to mask an unmaskable variable value
    $row
      .find(this.inputMap.secret_value.selector)
      .toggleClass(invalidInputClass, isMaskedChecked && !isValueMaskable);
    $row
      .find('.js-secret-value-placeholder')
      .toggleClass(invalidInputClass, isMaskedChecked && !isValueMaskable);
    $row.find('.masking-validation-error').toggle(isMaskedChecked && !isValueMaskable);
  }

  toggleEnableRow(isEnabled = true) {
    this.$container.find(this.inputMap.key.selector).attr('disabled', !isEnabled);
    this.$container.find('.js-row-remove-button').attr('disabled', !isEnabled);
  }

  hideValues() {
    this.secretValues.updateDom(false);
  }

  getAllData() {
    // Ignore the last empty row because we don't want to try persist
    // a blank variable and run into validation problems.
    const validRows = this.$container
      .find('.js-row')
      .toArray()
      .slice(0, -1);

    return validRows.map(rowEl => {
      const resultant = {};
      Object.keys(this.inputMap).forEach(name => {
        const entry = this.inputMap[name];
        const $input = $(rowEl).find(entry.selector);
        if ($input.length) {
          resultant[name] = $input.val();
        }
      });

      return resultant;
    });
  }

  getEnvironmentValues() {
    const valueMap = this.$container
      .find(this.inputMap.environment_scope.selector)
      .toArray()
      .reduce(
        (prevValueMap, envInput) => ({
          ...prevValueMap,
          [envInput.value]: envInput.value,
        }),
        {},
      );

    return Object.keys(valueMap).map(createEnvironmentItem);
  }

  refreshDropdownData() {
    this.$container.find('.js-row').each((index, rowEl) => {
      const environmentDropdown = this.environmentDropdownMap.get(rowEl);
      if (environmentDropdown) {
        environmentDropdown.refreshData();
      }
    });
  }
}
