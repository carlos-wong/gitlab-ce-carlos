import { __ } from '~/locale';

export default class U2FError {
  constructor(errorCode, u2fFlowType) {
    this.errorCode = errorCode;
    this.message = this.message.bind(this);
    this.httpsDisabled = window.location.protocol !== 'https:';
    this.u2fFlowType = u2fFlowType;
  }

  message() {
    if (this.errorCode === window.u2f.ErrorCodes.BAD_REQUEST && this.httpsDisabled) {
      return __(
        'U2F only works with HTTPS-enabled websites. Contact your administrator for more details.',
      );
    } else if (this.errorCode === window.u2f.ErrorCodes.DEVICE_INELIGIBLE) {
      if (this.u2fFlowType === 'authenticate') {
        return __('This device has not been registered with us.');
      }
      if (this.u2fFlowType === 'register') {
        return __('This device has already been registered with us.');
      }
    }
    return __('There was a problem communicating with your device.');
  }
}
