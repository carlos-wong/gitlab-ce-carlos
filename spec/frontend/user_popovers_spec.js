import { within } from '@testing-library/dom';
import { loadHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import UsersCache from '~/lib/utils/users_cache';
import initUserPopovers from '~/user_popovers';
import waitForPromises from 'helpers/wait_for_promises';

jest.mock('~/api/user_api', () => ({
  followUser: jest.fn().mockResolvedValue({}),
  unfollowUser: jest.fn().mockResolvedValue({}),
}));

describe('User Popovers', () => {
  const fixtureTemplate = 'merge_requests/merge_request_with_mentions.html';

  const selector = '.js-user-link[data-user], .js-user-link[data-user-id]';
  const findFixtureLinks = () => Array.from(document.querySelectorAll(selector));
  const createUserLink = () => {
    const link = document.createElement('a');

    link.classList.add('js-user-link');
    link.dataset.user = '1';

    return link;
  };
  const findPopovers = () => {
    return Array.from(document.querySelectorAll('[data-testid="user-popover"]'));
  };

  const dummyUser = { name: 'root', username: 'root', is_followed: false };
  const dummyUserStatus = { message: 'active' };

  const triggerEvent = (eventName, el) => {
    const event = new MouseEvent(eventName, {
      bubbles: true,
      cancelable: true,
      view: window,
    });

    el.dispatchEvent(event);
  };

  beforeEach(() => {
    loadHTMLFixture(fixtureTemplate);

    const usersCacheSpy = () => Promise.resolve(dummyUser);
    jest.spyOn(UsersCache, 'retrieveById').mockImplementation((userId) => usersCacheSpy(userId));

    const userStatusCacheSpy = () => Promise.resolve(dummyUserStatus);
    jest
      .spyOn(UsersCache, 'retrieveStatusById')
      .mockImplementation((userId) => userStatusCacheSpy(userId));
    jest.spyOn(UsersCache, 'updateById');

    initUserPopovers((popoverInstance) => {
      const mountingRoot = document.createElement('div');
      document.body.appendChild(mountingRoot);
      popoverInstance.$mount(mountingRoot);
    });
  });

  afterEach(() => {
    resetHTMLFixture();
  });

  describe('shows a placeholder popover on hover', () => {
    let linksWithUsers;
    beforeEach(() => {
      linksWithUsers = findFixtureLinks();
      linksWithUsers.forEach((el) => {
        triggerEvent('mouseover', el);
      });
    });

    it('for initial links', () => {
      expect(findPopovers().length).toBe(linksWithUsers.length);
    });

    it('for elements added after initial load', async () => {
      const addedLinks = [createUserLink(), createUserLink()];
      addedLinks.forEach((link) => {
        document.body.appendChild(link);
      });

      jest.runOnlyPendingTimers();

      addedLinks.forEach((link) => {
        triggerEvent('mouseover', link);
      });

      expect(findPopovers().length).toBe(linksWithUsers.length + addedLinks.length);
    });
  });

  it('does not initialize the popovers for group references', async () => {
    const [groupLink] = Array.from(document.querySelectorAll('.js-user-link[data-group]'));

    triggerEvent('mouseover', groupLink);
    jest.runOnlyPendingTimers();

    expect(findPopovers().length).toBe(0);
  });

  it('does not initialize the popovers for @all references', async () => {
    const [projectLink] = Array.from(document.querySelectorAll('.js-user-link[data-project]'));

    triggerEvent('mouseover', projectLink);
    jest.runOnlyPendingTimers();

    expect(findPopovers().length).toBe(0);
  });

  it('does not initialize the user popovers twice for the same element', async () => {
    const [firstUserLink] = findFixtureLinks();
    triggerEvent('mouseover', firstUserLink);
    jest.runOnlyPendingTimers();
    triggerEvent('mouseleave', firstUserLink);
    jest.runOnlyPendingTimers();
    triggerEvent('mouseover', firstUserLink);
    jest.runOnlyPendingTimers();

    expect(findPopovers().length).toBe(1);
  });

  describe('when user link emits mouseenter event with empty user cache', () => {
    let userLink;

    beforeEach(() => {
      UsersCache.retrieveById.mockReset();

      [userLink] = findFixtureLinks();

      triggerEvent('mouseover', userLink);
    });

    it('populates popover with preloaded user data', () => {
      const { name, userId, username } = userLink.dataset;

      expect(userLink.user).toEqual(
        expect.objectContaining({
          name,
          userId,
          username,
        }),
      );
    });
  });

  describe('when user link emits mouseenter event', () => {
    let userLink;

    beforeEach(() => {
      [userLink] = findFixtureLinks();

      triggerEvent('mouseover', userLink);
    });

    it('removes title attribute from user links', () => {
      expect(userLink.getAttribute('title')).toBeFalsy();
      expect(userLink.dataset.originalTitle).toBeFalsy();
    });

    it('fetches user info and status from the user cache', () => {
      const { userId } = userLink.dataset;

      expect(UsersCache.retrieveById).toHaveBeenCalledWith(userId);
      expect(UsersCache.retrieveStatusById).toHaveBeenCalledWith(userId);
    });

    it('removes aria-describedby attribute from the user link on mouseleave', () => {
      userLink.setAttribute('aria-describedby', 'popover');
      triggerEvent('mouseleave', userLink);

      expect(userLink.getAttribute('aria-describedby')).toBe(null);
    });

    it('updates toggle follow button and `UsersCache` when toggle follow button is clicked', async () => {
      const [firstPopover] = findPopovers();
      const withinFirstPopover = within(firstPopover);
      const findFollowButton = () => withinFirstPopover.queryByRole('button', { name: 'Follow' });
      const findUnfollowButton = () =>
        withinFirstPopover.queryByRole('button', { name: 'Unfollow' });

      jest.runOnlyPendingTimers();

      const { userId } = document.querySelector(selector).dataset;

      triggerEvent('click', findFollowButton());

      await waitForPromises();

      expect(findUnfollowButton()).not.toBe(null);
      expect(UsersCache.updateById).toHaveBeenCalledWith(userId, { is_followed: true });

      triggerEvent('click', findUnfollowButton());

      await waitForPromises();

      expect(findFollowButton()).not.toBe(null);
      expect(UsersCache.updateById).toHaveBeenCalledWith(userId, { is_followed: false });
    });
  });
});
