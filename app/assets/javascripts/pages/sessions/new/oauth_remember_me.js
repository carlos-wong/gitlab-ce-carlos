import $ from 'jquery';
import { mergeUrlParams, removeParams } from '~/lib/utils/url_utility';

/**
 * OAuth-based login buttons have a separate "remember me" checkbox.
 *
 * Toggling this checkbox adds/removes a `remember_me` parameter to the
 * login buttons' href, which is passed on to the omniauth callback.
 */

export default class OAuthRememberMe {
  constructor(opts = {}) {
    this.container = opts.container || '';
    this.loginLinkSelector = '.oauth-login';
  }

  bindEvents() {
    $('#remember_me', this.container).on('click', this.toggleRememberMe);
  }

  toggleRememberMe(event) {
    const rememberMe = $(event.target).is(':checked');

    $('.oauth-login', this.container).each((i, element) => {
      const href = $(element).attr('href');

      if (rememberMe) {
        $(element).attr('href', mergeUrlParams({ remember_me: 1 }, href));
      } else {
        $(element).attr('href', removeParams(['remember_me'], href));
      }
    });
  }
}
