import createFlash from '~/flash';
import axios from '~/lib/utils/axios_utils';
import { __ } from '~/locale';

export default class PayloadPreviewer {
  constructor(trigger) {
    this.trigger = trigger;
    this.isVisible = false;
    this.isInserted = false;
  }

  init() {
    this.spinner = this.trigger.querySelector('.js-spinner');
    this.text = this.trigger.querySelector('.js-text');

    this.trigger.addEventListener('click', (event) => {
      event.preventDefault();

      if (this.isVisible) return this.hidePayload();

      return this.requestPayload();
    });
  }

  getContainer() {
    return document.querySelector(this.trigger.dataset.payloadSelector);
  }

  requestPayload() {
    if (this.isInserted) return this.showPayload();

    this.spinner.classList.add('gl-display-inline-flex');

    const container = this.getContainer();

    return axios
      .get(container.dataset.endpoint, {
        responseType: 'text',
      })
      .then(({ data }) => {
        this.spinner.classList.remove('gl-display-inline-flex');
        this.insertPayload(data);
      })
      .catch(() => {
        this.spinner.classList.remove('gl-display-inline-flex');
        createFlash({
          message: __('Error fetching payload data.'),
        });
      });
  }

  hidePayload() {
    this.isVisible = false;
    this.getContainer().classList.add('gl-display-none');
    this.text.textContent = __('Preview payload');
  }

  showPayload() {
    this.isVisible = true;
    this.getContainer().classList.remove('gl-display-none');
    this.text.textContent = __('Hide payload');
  }

  insertPayload(data) {
    this.isInserted = true;
    this.getContainer().innerHTML = data;
    this.showPayload();
  }
}
