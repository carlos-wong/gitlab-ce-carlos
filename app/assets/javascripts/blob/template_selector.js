/* eslint-disable class-methods-use-this */

import $ from 'jquery';
import '~/gl_dropdown';

export default class TemplateSelector {
  constructor({ dropdown, data, pattern, wrapper, editor, $input } = {}) {
    this.pattern = pattern;
    this.editor = editor;
    this.dropdown = dropdown;
    this.$dropdownContainer = wrapper;
    this.$filenameInput = $input || $('#file_name');
    this.$dropdownIcon = $('.fa-chevron-down', dropdown);

    this.initDropdown(dropdown, data);
    this.listenForFilenameInput();
    this.renderMatchedDropdown();
    this.initAutosizeUpdateEvent();
  }

  initDropdown(dropdown, data) {
    return $(dropdown).glDropdown({
      data,
      filterable: true,
      selectable: true,
      toggleLabel: item => item.name,
      search: {
        fields: ['name'],
      },
      clicked: options => this.onDropdownClicked(options),
      text: item => item.name,
    });
  }

  // Subclasses can override this method to conditionally prevent fetching file templates
  onDropdownClicked(options) {
    this.fetchFileTemplate(options);
  }

  initAutosizeUpdateEvent() {
    this.autosizeUpdateEvent = document.createEvent('Event');
    this.autosizeUpdateEvent.initEvent('autosize:update', true, false);
  }

  listenForFilenameInput() {
    return this.$filenameInput.on('keyup blur', e => this.renderMatchedDropdown(e));
  }

  renderMatchedDropdown() {
    if (!this.$filenameInput.length) {
      return null;
    }

    const filenameMatches = this.pattern.test(this.$filenameInput.val().trim());

    if (!filenameMatches) {
      return this.$dropdownContainer.addClass('hidden');
    }
    return this.$dropdownContainer.removeClass('hidden');
  }

  fetchFileTemplate(options) {
    const { e } = options;
    const item = options.selectedObj;

    e.preventDefault();
    return this.requestFile(item);
  }

  requestFile() {
    // This `requestFile` method is an abstract method that should
    // be added by all subclasses.
  }

  setEditorContent(file, { skipFocus } = {}) {
    if (!file) return;

    const newValue = file.content;

    this.editor.setValue(newValue, 1);

    if (!skipFocus) this.editor.focus();

    if (this.editor instanceof $) {
      this.editor.get(0).dispatchEvent(this.autosizeUpdateEvent);
      this.editor.trigger('input');
    }
  }

  getEditorContent() {
    return this.editor.getValue();
  }

  startLoadingSpinner() {
    this.$dropdownIcon.addClass('spinner').removeClass('fa-chevron-down');
  }

  stopLoadingSpinner() {
    this.$dropdownIcon.addClass('fa-chevron-down').removeClass('spinner');
  }
}
