import axios from '../../../lib/utils/axios_utils';
import { __ } from '../../../locale';
import flash from '../../../flash';

export default class UsagePingPayload {
  constructor(trigger, container) {
    this.trigger = trigger;
    this.container = container;
    this.isVisible = false;
    this.isInserted = false;
  }

  init() {
    this.spinner = this.trigger.querySelector('.js-spinner');
    this.text = this.trigger.querySelector('.js-text');

    this.trigger.addEventListener('click', event => {
      event.preventDefault();

      if (this.isVisible) return this.hidePayload();

      return this.requestPayload();
    });
  }

  requestPayload() {
    if (this.isInserted) return this.showPayload();

    this.spinner.classList.add('d-inline-flex');

    return axios
      .get(this.container.dataset.endpoint, {
        responseType: 'text',
      })
      .then(({ data }) => {
        this.spinner.classList.remove('d-inline-flex');
        this.insertPayload(data);
      })
      .catch(() => {
        this.spinner.classList.remove('d-inline-flex');
        flash(__('Error fetching usage ping data.'));
      });
  }

  hidePayload() {
    this.isVisible = false;
    this.container.classList.add('d-none');
    this.text.textContent = __('Preview payload');
  }

  showPayload() {
    this.isVisible = true;
    this.container.classList.remove('d-none');
    this.text.textContent = __('Hide payload');
  }

  insertPayload(data) {
    this.isInserted = true;
    this.container.innerHTML = data;
    this.showPayload();
  }
}
