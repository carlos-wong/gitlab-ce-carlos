import Vue from 'vue';
import { debounce } from 'lodash';
import UsersCache from './lib/utils/users_cache';
import UserPopover from './vue_shared/components/user_popover/user_popover.vue';
import { USER_POPOVER_DELAY } from './vue_shared/components/user_popover/constants';

const removeTitle = (el) => {
  // Removing titles so its not showing tooltips also

  el.dataset.originalTitle = '';
  el.setAttribute('title', '');
};

const getPreloadedUserInfo = (dataset) => {
  const userId = dataset.user || dataset.userId;
  const { username, name, avatarUrl } = dataset;

  return {
    userId,
    username,
    name,
    avatarUrl,
  };
};

/**
 * Adds a UserPopover component to the body, hands over as much data as the target element has in data attributes.
 * loads based on data-user-id more data about a user from the API and sets it on the popover
 */
const populateUserInfo = (user) => {
  const { userId } = user;

  return Promise.all([UsersCache.retrieveById(userId), UsersCache.retrieveStatusById(userId)]).then(
    ([userData, status]) => {
      if (userData) {
        Object.assign(user, {
          id: userId,
          avatarUrl: userData.avatar_url,
          bot: userData.bot,
          username: userData.username,
          name: userData.name,
          location: userData.location,
          bio: userData.bio,
          workInformation: userData.work_information,
          websiteUrl: userData.website_url,
          pronouns: userData.pronouns,
          localTime: userData.local_time,
          isFollowed: userData.is_followed,
          loaded: true,
        });
      }

      if (status) {
        Object.assign(user, {
          status,
        });
      }

      return user;
    },
  );
};

function createPopover(el, user) {
  removeTitle(el);
  const preloadedUserInfo = getPreloadedUserInfo(el.dataset);

  Object.assign(user, preloadedUserInfo);

  if (preloadedUserInfo.userId) {
    populateUserInfo(user);
  }
  const UserPopoverComponent = Vue.extend(UserPopover);
  return new UserPopoverComponent({
    propsData: {
      target: el,
      user,
      show: true,
      placement: el.dataset.placement || 'top',
    },
  });
}

function launchPopover(el, mountPopover) {
  if (el.user) return;

  const emptyUser = {
    location: null,
    bio: null,
    workInformation: null,
    status: null,
    isFollowed: false,
    loaded: false,
  };
  el.user = emptyUser;
  el.addEventListener(
    'mouseleave',
    ({ target }) => {
      target.removeAttribute('aria-describedby');
    },
    { once: true },
  );
  const popoverInstance = createPopover(el, emptyUser);

  const { userId } = el.dataset;

  popoverInstance.$on('follow', () => {
    UsersCache.updateById(userId, { is_followed: true });
    el.user.isFollowed = true;
  });

  popoverInstance.$on('unfollow', () => {
    UsersCache.updateById(userId, { is_followed: false });
    el.user.isFollowed = false;
  });

  mountPopover(popoverInstance);
}

const userLinkSelector = 'a.js-user-link[data-user], a.js-user-link[data-user-id]';

const getUserLinkNode = (node) => node.closest(userLinkSelector);

const lazyLaunchPopover = debounce((mountPopover, event) => {
  const userLink = getUserLinkNode(event.target);
  if (userLink) {
    launchPopover(userLink, mountPopover);
  }
}, USER_POPOVER_DELAY);

let hasAddedLazyPopovers = false;

export default function addPopovers(mountPopover = (instance) => instance.$mount()) {
  if (!hasAddedLazyPopovers) {
    document.addEventListener('mouseover', (event) => lazyLaunchPopover(mountPopover, event));
    hasAddedLazyPopovers = true;
  }
}
