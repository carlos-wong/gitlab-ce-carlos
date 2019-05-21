import _ from 'underscore';
import $ from 'jquery';

class DirtySubmitForm {
  constructor(form) {
    this.form = form;
    this.dirtyInputs = [];
    this.isDisabled = true;

    this.init();
  }

  init() {
    this.inputs = this.form.querySelectorAll('input, textarea, select');
    this.submits = this.form.querySelectorAll('input[type=submit], button[type=submit]');

    this.inputs.forEach(DirtySubmitForm.initInput);
    this.toggleSubmission();

    this.registerListeners();
  }

  registerListeners() {
    const throttledUpdateDirtyInput = _.throttle(
      event => this.updateDirtyInput(event),
      DirtySubmitForm.THROTTLE_DURATION,
    );
    this.form.addEventListener('input', throttledUpdateDirtyInput);
    this.form.addEventListener('change', throttledUpdateDirtyInput);
    $(this.form).on('change.select2', throttledUpdateDirtyInput);
    this.form.addEventListener('submit', event => this.formSubmit(event));
  }

  updateDirtyInput(event) {
    const { target } = event;

    if (!target.dataset.isDirtySubmitInput) return;

    this.updateDirtyInputs(target);
    this.toggleSubmission();
  }

  updateDirtyInputs(input) {
    const { name } = input;
    const isDirty =
      input.dataset.dirtySubmitOriginalValue !== DirtySubmitForm.inputCurrentValue(input);
    const indexOfInputName = this.dirtyInputs.indexOf(name);
    const isExisting = indexOfInputName !== -1;

    if (isDirty && !isExisting) this.dirtyInputs.push(name);
    if (!isDirty && isExisting) this.dirtyInputs.splice(indexOfInputName, 1);
  }

  toggleSubmission() {
    this.isDisabled = this.dirtyInputs.length === 0;
    this.submits.forEach(element => {
      element.disabled = this.isDisabled;
    });
  }

  formSubmit(event) {
    if (this.isDisabled) {
      event.preventDefault();
      event.stopImmediatePropagation();
    }

    return !this.isDisabled;
  }

  static initInput(element) {
    element.dataset.isDirtySubmitInput = true;
    element.dataset.dirtySubmitOriginalValue = DirtySubmitForm.inputCurrentValue(element);
  }

  static isInputCheckable(input) {
    return input.type === 'checkbox' || input.type === 'radio';
  }

  static inputCurrentValue(input) {
    return DirtySubmitForm.isInputCheckable(input) ? input.checked.toString() : input.value;
  }
}

DirtySubmitForm.THROTTLE_DURATION = 500;

export default DirtySubmitForm;
