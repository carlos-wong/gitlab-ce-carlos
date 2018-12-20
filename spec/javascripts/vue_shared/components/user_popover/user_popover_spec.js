import Vue from 'vue';
import userPopover from '~/vue_shared/components/user_popover/user_popover.vue';
import mountComponent from 'spec/helpers/vue_mount_component_helper';

const DEFAULT_PROPS = {
  loaded: true,
  user: {
    username: 'root',
    name: 'Administrator',
    location: 'Vienna',
    bio: null,
    organization: null,
    status: null,
  },
};

const UserPopover = Vue.extend(userPopover);

describe('User Popover Component', () => {
  let vm;

  beforeEach(() => {
    setFixtures(`
      <a href="/root" data-user-id="1" class="js-user-link" title="testuser">
        Root
      </a>
    `);
  });

  afterEach(() => {
    vm.$destroy();
  });

  describe('Empty', () => {
    beforeEach(() => {
      vm = mountComponent(UserPopover, {
        target: document.querySelector('.js-user-link'),
        user: {
          name: null,
          username: null,
          location: null,
          bio: null,
          organization: null,
          status: null,
        },
      });
    });

    it('should return skeleton loaders', () => {
      expect(vm.$el.querySelectorAll('.animation-container').length).toBe(4);
    });
  });

  describe('basic data', () => {
    it('should show basic fields', () => {
      vm = mountComponent(UserPopover, {
        ...DEFAULT_PROPS,
        target: document.querySelector('.js-user-link'),
      });

      expect(vm.$el.textContent).toContain(DEFAULT_PROPS.user.name);
      expect(vm.$el.textContent).toContain(DEFAULT_PROPS.user.username);
      expect(vm.$el.textContent).toContain(DEFAULT_PROPS.user.location);
    });
  });

  describe('job data', () => {
    it('should show only bio if no organization is available', () => {
      const testProps = Object.assign({}, DEFAULT_PROPS);
      testProps.user.bio = 'Engineer';

      vm = mountComponent(UserPopover, {
        ...testProps,
        target: document.querySelector('.js-user-link'),
      });

      expect(vm.$el.textContent).toContain('Engineer');
    });

    it('should show only organization if no bio is available', () => {
      const testProps = Object.assign({}, DEFAULT_PROPS);
      testProps.user.organization = 'GitLab';

      vm = mountComponent(UserPopover, {
        ...testProps,
        target: document.querySelector('.js-user-link'),
      });

      expect(vm.$el.textContent).toContain('GitLab');
    });

    it('should have full job line when we have bio and organization', () => {
      const testProps = Object.assign({}, DEFAULT_PROPS);
      testProps.user.bio = 'Engineer';
      testProps.user.organization = 'GitLab';

      vm = mountComponent(UserPopover, {
        ...DEFAULT_PROPS,
        target: document.querySelector('.js-user-link'),
      });

      expect(vm.$el.textContent).toContain('Engineer at GitLab');
    });

    it('should not encode special characters when we have bio and organization', () => {
      const testProps = Object.assign({}, DEFAULT_PROPS);
      testProps.user.bio = 'Manager & Team Lead';
      testProps.user.organization = 'GitLab';

      vm = mountComponent(UserPopover, {
        ...DEFAULT_PROPS,
        target: document.querySelector('.js-user-link'),
      });

      expect(vm.$el.textContent).toContain('Manager & Team Lead at GitLab');
    });
  });

  describe('status data', () => {
    it('should show only message', () => {
      const testProps = Object.assign({}, DEFAULT_PROPS);
      testProps.user.status = { message: 'Hello World' };

      vm = mountComponent(UserPopover, {
        ...DEFAULT_PROPS,
        target: document.querySelector('.js-user-link'),
      });

      expect(vm.$el.textContent).toContain('Hello World');
    });

    it('should show message and emoji', () => {
      const testProps = Object.assign({}, DEFAULT_PROPS);
      testProps.user.status = { emoji: 'basketball_player', message: 'Hello World' };

      vm = mountComponent(UserPopover, {
        ...DEFAULT_PROPS,
        target: document.querySelector('.js-user-link'),
        status: { emoji: 'basketball_player', message: 'Hello World' },
      });

      expect(vm.$el.textContent).toContain('Hello World');
      expect(vm.$el.innerHTML).toContain('<gl-emoji data-name="basketball_player"');
    });
  });
});
