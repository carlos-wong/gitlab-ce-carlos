/* global $ */

import jQuery from 'jquery';
import Cookies from 'js-cookie';

// bootstrap webpack, common libs, polyfills, and behaviors
import './webpack';
import './commons';
import './behaviors';

// lib/utils
import { handleLocationHash, addSelectOnFocusBehaviour } from './lib/utils/common_utils';
import { localTimeAgo } from './lib/utils/datetime_utility';
import { getLocationHash, visitUrl } from './lib/utils/url_utility';

// everything else
import loadAwardsHandler from './awards_handler';
import bp from './breakpoints';
import Flash, { removeFlashClickListener } from './flash';
import './gl_dropdown';
import initTodoToggle from './header';
import initImporterStatus from './importer_status';
import initLayoutNav from './layout_nav';
import './feature_highlight/feature_highlight_options';
import LazyLoader from './lazy_loader';
import initLogoAnimation from './logo';
import './frequent_items';
import initBreadcrumbs from './breadcrumb';
import initUsagePingConsent from './usage_ping_consent';
import initPerformanceBar from './performance_bar';
import initSearchAutocomplete from './search_autocomplete';
import GlFieldErrors from './gl_field_errors';
import initUserPopovers from './user_popovers';

// expose jQuery as global (TODO: remove these)
window.jQuery = jQuery;
window.$ = jQuery;

// inject test utilities if necessary
if (process.env.NODE_ENV !== 'production' && gon && gon.test_env) {
  $.fx.off = true;
  import(/* webpackMode: "eager" */ './test_utils/');
}

document.addEventListener('beforeunload', () => {
  // Unbind scroll events
  $(document).off('scroll');
  // Close any open tooltips
  $('.has-tooltip, [data-toggle="tooltip"]').tooltip('dispose');
  // Close any open popover
  $('[data-toggle="popover"]').popover('dispose');
});

window.addEventListener('hashchange', handleLocationHash);
window.addEventListener(
  'load',
  function onLoad() {
    window.removeEventListener('load', onLoad, false);
    handleLocationHash();
  },
  false,
);

gl.lazyLoader = new LazyLoader({
  scrollContainer: window,
  observerNode: '#content-body',
});

// Put all initialisations here that can also wait after everything is rendered and ready
function deferredInitialisation() {
  const $body = $('body');

  initBreadcrumbs();
  initImporterStatus();
  initTodoToggle();
  initLogoAnimation();
  initUsagePingConsent();
  initUserPopovers();

  if (document.querySelector('.search')) initSearchAutocomplete();

  addSelectOnFocusBehaviour('.js-select-on-focus');

  $('.remove-row').on('ajax:success', function removeRowAjaxSuccessCallback() {
    $(this)
      .tooltip('dispose')
      .closest('li')
      .fadeOut();
  });

  $('.js-remove-tr').on('ajax:before', function removeTRAjaxBeforeCallback() {
    $(this).hide();
  });

  $('.js-remove-tr').on('ajax:success', function removeTRAjaxSuccessCallback() {
    $(this)
      .closest('tr')
      .fadeOut();
  });

  // Initialize select2 selects
  if ($('select.select2').length) {
    import(/* webpackChunkName: 'select2' */ 'select2/select2')
      .then(() => {
        $('select.select2').select2({
          width: 'resolve',
          dropdownAutoWidth: true,
        });

        // Close select2 on escape
        $('.js-select2').on('select2-close', () => {
          setTimeout(() => {
            $('.select2-container-active').removeClass('select2-container-active');
            $(':focus').blur();
          }, 1);
        });
      })
      .catch(() => {});
  }

  // Initialize tooltips
  $body.tooltip({
    selector: '.has-tooltip, [data-toggle="tooltip"]',
    trigger: 'hover',
    boundary: 'viewport',
  });

  // Initialize popovers
  $body.popover({
    selector: '[data-toggle="popover"]',
    trigger: 'focus',
    // set the viewport to the main content, excluding the navigation bar, so
    // the navigation can't overlap the popover
    viewport: '.layout-page',
  });

  loadAwardsHandler();
}

document.addEventListener('DOMContentLoaded', () => {
  const $body = $('body');
  const $document = $(document);
  const $window = $(window);
  const $sidebarGutterToggle = $('.js-sidebar-toggle');
  let bootstrapBreakpoint = bp.getBreakpointSize();

  if (document.querySelector('#js-peek')) initPerformanceBar({ container: '#js-peek' });

  initLayoutNav();

  // Set the default path for all cookies to GitLab's root directory
  Cookies.defaults.path = gon.relative_url_root || '/';

  // `hashchange` is not triggered when link target is already in window.location
  $body.on('click', 'a[href^="#"]', function clickHashLinkCallback() {
    const href = this.getAttribute('href');
    if (href.substr(1) === getLocationHash()) {
      setTimeout(handleLocationHash, 1);
    }
  });

  if (bootstrapBreakpoint === 'xs') {
    const $rightSidebar = $('aside.right-sidebar, .layout-page');

    $rightSidebar.removeClass('right-sidebar-expanded').addClass('right-sidebar-collapsed');
  }

  // prevent default action for disabled buttons
  $('.btn').click(function clickDisabledButtonCallback(e) {
    if ($(this).hasClass('disabled')) {
      e.preventDefault();
      e.stopImmediatePropagation();
      return false;
    }

    return true;
  });

  localTimeAgo($('abbr.timeago, .js-timeago'), true);

  // Form submitter
  $('.trigger-submit').on('change', function triggerSubmitCallback() {
    $(this)
      .parents('form')
      .submit();
  });

  // Disable form buttons while a form is submitting
  $body.on('ajax:complete, ajax:beforeSend, submit', 'form', function ajaxCompleteCallback(e) {
    const $buttons = $('[type="submit"], .js-disable-on-submit', this);
    switch (e.type) {
      case 'ajax:beforeSend':
      case 'submit':
        return $buttons.disable();
      default:
        return $buttons.enable();
    }
  });

  $(document).ajaxError((e, xhrObj) => {
    const ref = xhrObj.status;

    if (ref === 401) {
      Flash('You need to be logged in.');
    } else if (ref === 404 || ref === 500) {
      Flash('Something went wrong on our end.');
    }
  });

  $('.navbar-toggler').on('click', () => {
    $('.header-content').toggleClass('menu-expanded');
  });

  // Commit show suppressed diff
  $document.on('click', '.diff-content .js-show-suppressed-diff', function showDiffCallback() {
    const $container = $(this).parent();
    $container.next('table').show();
    $container.remove();
  });

  // Show/hide comments on diff
  $body.on('click', '.js-toggle-diff-comments', function toggleDiffCommentsCallback(e) {
    const $this = $(this);
    const notesHolders = $this.closest('.diff-file').find('.notes_holder');

    e.preventDefault();

    $this.toggleClass('active');

    if ($this.hasClass('active')) {
      notesHolders
        .show()
        .find('.hide, .content')
        .show();
    } else {
      notesHolders
        .hide()
        .find('.content')
        .hide();
    }

    $(document).trigger('toggle.comments');
  });

  $document.on('breakpoint:change', (e, breakpoint) => {
    if (breakpoint === 'sm' || breakpoint === 'xs') {
      const $gutterIcon = $sidebarGutterToggle.find('i');
      if ($gutterIcon.hasClass('fa-angle-double-right')) {
        $sidebarGutterToggle.trigger('click');
      }
    }
  });

  function fitSidebarForSize() {
    const oldBootstrapBreakpoint = bootstrapBreakpoint;
    bootstrapBreakpoint = bp.getBreakpointSize();

    if (bootstrapBreakpoint !== oldBootstrapBreakpoint) {
      $document.trigger('breakpoint:change', [bootstrapBreakpoint]);
    }
  }

  $window.on('resize.app', fitSidebarForSize);

  $('form.filter-form').on('submit', function filterFormSubmitCallback(event) {
    const link = document.createElement('a');
    link.href = this.action;

    const action = `${this.action}${link.search === '' ? '?' : '&'}`;

    event.preventDefault();
    visitUrl(`${action}${$(this).serialize()}`);
  });

  const flashContainer = document.querySelector('.flash-container');

  if (flashContainer && flashContainer.children.length) {
    flashContainer
      .querySelectorAll('.flash-alert, .flash-notice, .flash-success')
      .forEach(flashEl => {
        removeFlashClickListener(flashEl);
      });
  }

  // initialize field errors
  $('.gl-show-field-errors').each((i, form) => new GlFieldErrors(form));

  requestIdleCallback(deferredInitialisation);
});
