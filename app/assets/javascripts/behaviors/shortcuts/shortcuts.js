import $ from 'jquery';
import Cookies from 'js-cookie';
import Mousetrap from 'mousetrap';
import Vue from 'vue';
import { disableShortcuts, shouldDisableShortcuts } from './shortcuts_toggle';
import ShortcutsToggle from './shortcuts_toggle.vue';
import axios from '../../lib/utils/axios_utils';
import { refreshCurrentPage, visitUrl } from '../../lib/utils/url_utility';
import findAndFollowLink from '../../lib/utils/navigation_utility';
import { parseBoolean, getCspNonceValue } from '~/lib/utils/common_utils';

const defaultStopCallback = Mousetrap.stopCallback;
Mousetrap.stopCallback = (e, element, combo) => {
  if (['ctrl+shift+p', 'command+shift+p'].indexOf(combo) !== -1) {
    return false;
  }

  return defaultStopCallback(e, element, combo);
};

function initToggleButton() {
  return new Vue({
    el: document.querySelector('.js-toggle-shortcuts'),
    render(createElement) {
      return createElement(ShortcutsToggle);
    },
  });
}

export default class Shortcuts {
  constructor() {
    this.onToggleHelp = this.onToggleHelp.bind(this);
    this.enabledHelp = [];

    Mousetrap.bind('?', this.onToggleHelp);
    Mousetrap.bind('s', Shortcuts.focusSearch);
    Mousetrap.bind('f', this.focusFilter.bind(this));
    Mousetrap.bind('p b', Shortcuts.onTogglePerfBar);

    const findFileURL = document.body.dataset.findFile;

    Mousetrap.bind('shift+t', () => findAndFollowLink('.shortcuts-todos'));
    Mousetrap.bind('shift+a', () => findAndFollowLink('.dashboard-shortcuts-activity'));
    Mousetrap.bind('shift+i', () => findAndFollowLink('.dashboard-shortcuts-issues'));
    Mousetrap.bind('shift+m', () => findAndFollowLink('.dashboard-shortcuts-merge_requests'));
    Mousetrap.bind('shift+p', () => findAndFollowLink('.dashboard-shortcuts-projects'));
    Mousetrap.bind('shift+g', () => findAndFollowLink('.dashboard-shortcuts-groups'));
    Mousetrap.bind('shift+l', () => findAndFollowLink('.dashboard-shortcuts-milestones'));
    Mousetrap.bind('shift+s', () => findAndFollowLink('.dashboard-shortcuts-snippets'));

    Mousetrap.bind(['ctrl+shift+p', 'command+shift+p'], Shortcuts.toggleMarkdownPreview);

    if (typeof findFileURL !== 'undefined' && findFileURL !== null) {
      Mousetrap.bind('t', () => {
        visitUrl(findFileURL);
      });
    }

    $(document).on('click.more_help', '.js-more-help-button', function clickMoreHelp(e) {
      $(this).remove();
      e.preventDefault();
    });

    $('.js-shortcuts-modal-trigger')
      .off('click')
      .on('click', this.onToggleHelp);

    if (shouldDisableShortcuts()) {
      disableShortcuts();
    }
  }

  onToggleHelp(e) {
    if (e.preventDefault) {
      e.preventDefault();
    }

    Shortcuts.toggleHelp(this.enabledHelp);
  }

  static onTogglePerfBar(e) {
    e.preventDefault();
    const performanceBarCookieName = 'perf_bar_enabled';
    if (parseBoolean(Cookies.get(performanceBarCookieName))) {
      Cookies.set(performanceBarCookieName, 'false', { path: '/' });
    } else {
      Cookies.set(performanceBarCookieName, 'true', { path: '/' });
    }
    refreshCurrentPage();
  }

  static toggleMarkdownPreview(e) {
    // Check if short-cut was triggered while in Write Mode
    const $target = $(e.target);
    const $form = $target.closest('form');

    if ($target.hasClass('js-note-text')) {
      $('.js-md-preview-button', $form).focus();
    }
    $(document).triggerHandler('markdown-preview:toggle', [e]);
  }

  static toggleHelp(location) {
    const $modal = $('#modal-shortcuts');

    if ($modal.length) {
      $modal.modal('toggle');
      return null;
    }

    return axios
      .get(gon.shortcuts_path, {
        responseType: 'text',
      })
      .then(({ data }) => {
        $.globalEval(data, { nonce: getCspNonceValue() });

        if (location && location.length > 0) {
          const results = [];
          for (let i = 0, len = location.length; i < len; i += 1) {
            results.push($(location[i]).show());
          }
          return results;
        }

        return $('.js-more-help-button').remove();
      })
      .then(initToggleButton);
  }

  focusFilter(e) {
    if (!this.filterInput) {
      this.filterInput = $('input[type=search]', '.nav-controls');
    }
    this.filterInput.focus();
    e.preventDefault();
  }

  static focusSearch(e) {
    $('#search').focus();

    if (e.preventDefault) {
      e.preventDefault();
    }
  }
}
