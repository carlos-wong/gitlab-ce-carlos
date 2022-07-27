import Vue from 'vue';
import { highCountTrim } from '~/lib/utils/text_utility';
import Tracking from '~/tracking';
import Translate from '~/vue_shared/translate';

/**
 * Updates todo counter when todos are toggled.
 * When count is 0, we hide the badge.
 *
 * @param {jQuery.Event} e
 * @param {String} count
 */
export default function initTodoToggle() {
  document.addEventListener('todo:toggle', (e) => {
    const updatedCount = e.detail.count || 0;
    const todoPendingCount = document.querySelector('.js-todos-count');

    if (todoPendingCount) {
      todoPendingCount.textContent = highCountTrim(updatedCount);
      if (updatedCount === 0) {
        todoPendingCount.classList.add('hidden');
      } else {
        todoPendingCount.classList.remove('hidden');
      }
    }
  });
}

function initStatusTriggers() {
  const setStatusModalTriggerEl = document.querySelector('.js-set-status-modal-trigger');

  if (setStatusModalTriggerEl) {
    setStatusModalTriggerEl.addEventListener('click', () => {
      import(
        /* webpackChunkName: 'statusModalBundle' */ './set_status_modal/set_status_modal_wrapper.vue'
      )
        .then(({ default: SetStatusModalWrapper }) => {
          const setStatusModalWrapperEl = document.querySelector('.js-set-status-modal-wrapper');
          const statusModalElement = document.createElement('div');
          setStatusModalWrapperEl.appendChild(statusModalElement);

          Vue.use(Translate);

          // eslint-disable-next-line no-new
          new Vue({
            el: statusModalElement,
            data() {
              const {
                currentEmoji,
                defaultEmoji,
                currentMessage,
                currentAvailability,
                currentClearStatusAfter,
              } = setStatusModalWrapperEl.dataset;

              return {
                currentEmoji,
                defaultEmoji,
                currentMessage,
                currentAvailability,
                currentClearStatusAfter,
              };
            },
            render(createElement) {
              const {
                currentEmoji,
                defaultEmoji,
                currentMessage,
                currentAvailability,
                currentClearStatusAfter,
              } = this;

              return createElement(SetStatusModalWrapper, {
                props: {
                  currentEmoji,
                  defaultEmoji,
                  currentMessage,
                  currentAvailability,
                  currentClearStatusAfter,
                },
              });
            },
          });
        })
        .catch(() => {});
    });
  }
}

function trackShowUserDropdownLink(trackEvent, elToTrack, el) {
  const { trackLabel, trackProperty } = elToTrack.dataset;

  el.addEventListener('shown.bs.dropdown', () => {
    Tracking.event(document.body.dataset.page, trackEvent, {
      label: trackLabel,
      property: trackProperty,
    });
  });
}
export function initNavUserDropdownTracking() {
  const el = document.querySelector('.js-nav-user-dropdown');
  const buyEl = document.querySelector('.js-buy-pipeline-minutes-link');

  if (el && buyEl) {
    trackShowUserDropdownLink('show_buy_ci_minutes', buyEl, el);
  }
}

requestIdleCallback(initStatusTriggers);
requestIdleCallback(initNavUserDropdownTracking);
