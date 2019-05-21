import $ from 'jquery';
import axios from '../lib/utils/axios_utils';
import flash from '../flash';
import { __ } from '~/locale';

export default class IntegrationSettingsForm {
  constructor(formSelector) {
    this.$form = $(formSelector);

    // Form Metadata
    this.canTestService = this.$form.data('canTest');
    this.testEndPoint = this.$form.data('testUrl');

    // Form Child Elements
    this.$serviceToggle = this.$form.find('#service_active');
    this.$submitBtn = this.$form.find('button[type="submit"]');
    this.$submitBtnLoader = this.$submitBtn.find('.js-btn-spinner');
    this.$submitBtnLabel = this.$submitBtn.find('.js-btn-label');
  }

  init() {
    // Initialize View
    this.toggleServiceState(this.$serviceToggle.is(':checked'));

    // Bind Event Listeners
    this.$serviceToggle.on('change', e => this.handleServiceToggle(e));
    this.$submitBtn.on('click', e => this.handleSettingsSave(e));
  }

  handleSettingsSave(e) {
    // Check if Service is marked active, as if not marked active,
    // We can skip testing it and directly go ahead to allow form to
    // be submitted
    if (!this.$serviceToggle.is(':checked')) {
      return;
    }

    // Service was marked active so now we check;
    // 1) If form contents are valid
    // 2) If this service can be tested
    // If both conditions are true, we override form submission
    // and test the service using provided configuration.
    if (this.$form.get(0).checkValidity() && this.canTestService) {
      e.preventDefault();
      this.testSettings(this.$form.serialize());
    }
  }

  handleServiceToggle(e) {
    this.toggleServiceState($(e.currentTarget).is(':checked'));
  }

  /**
   * Change Form's validation enforcement based on service status (active/inactive)
   */
  toggleServiceState(serviceActive) {
    this.toggleSubmitBtnLabel(serviceActive);
    if (serviceActive) {
      this.$form.removeAttr('novalidate');
    } else if (!this.$form.attr('novalidate')) {
      this.$form.attr('novalidate', 'novalidate');
    }
  }

  /**
   * Toggle Submit button label based on Integration status and ability to test service
   */
  toggleSubmitBtnLabel(serviceActive) {
    let btnLabel = __('Save changes');

    if (serviceActive && this.canTestService) {
      btnLabel = __('Test settings and save changes');
    }

    this.$submitBtnLabel.text(btnLabel);
  }

  /**
   * Toggle Submit button state based on provided boolean value of `saveTestActive`
   * When enabled, it does two things, and reverts back when disabled
   *
   * 1. It shows load spinner on submit button
   * 2. Makes submit button disabled
   */
  toggleSubmitBtnState(saveTestActive) {
    if (saveTestActive) {
      this.$submitBtn.disable();
      this.$submitBtnLoader.removeClass('hidden');
    } else {
      this.$submitBtn.enable();
      this.$submitBtnLoader.addClass('hidden');
    }
  }

  /**
   * Test Integration config
   */
  testSettings(formData) {
    this.toggleSubmitBtnState(true);

    return axios
      .put(this.testEndPoint, formData)
      .then(({ data }) => {
        if (data.error) {
          let flashActions;

          if (data.test_failed) {
            flashActions = {
              title: __('Save anyway'),
              clickHandler: e => {
                e.preventDefault();
                this.$form.submit();
              },
            };
          }

          flash(`${data.message} ${data.service_response}`, 'alert', document, flashActions);
        } else {
          this.$form.submit();
        }

        this.toggleSubmitBtnState(false);
      })
      .catch(() => {
        flash(__('Something went wrong on our end.'));
        this.toggleSubmitBtnState(false);
      });
  }
}
