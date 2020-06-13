import Vue from 'vue';
import { mountComponentWithStore } from 'helpers/vue_mount_component_helper';
import { GROUP_BADGE, PROJECT_BADGE } from '~/badges/constants';
import store from '~/badges/store';
import BadgeList from '~/badges/components/badge_list.vue';
import { createDummyBadge } from '../dummy_badge';

describe('BadgeList component', () => {
  const Component = Vue.extend(BadgeList);
  const numberOfDummyBadges = 3;
  let vm;

  beforeEach(() => {
    setFixtures('<div id="dummy-element"></div>');
    const badges = [];
    for (let id = 0; id < numberOfDummyBadges; id += 1) {
      badges.push({ id, ...createDummyBadge() });
    }
    store.replaceState({
      ...store.state,
      badges,
      kind: PROJECT_BADGE,
      isLoading: false,
    });

    // Can be removed once GlLoadingIcon no longer throws a warning
    jest.spyOn(global.console, 'warn').mockImplementation(() => jest.fn());

    vm = mountComponentWithStore(Component, {
      el: '#dummy-element',
      store,
    });
  });

  afterEach(() => {
    vm.$destroy();
  });

  it('renders a header with the badge count', () => {
    const header = vm.$el.querySelector('.card-header');

    expect(header).toHaveText(new RegExp(`Your badges\\s+${numberOfDummyBadges}`));
  });

  it('renders a row for each badge', () => {
    const rows = vm.$el.querySelectorAll('.gl-responsive-table-row');

    expect(rows).toHaveLength(numberOfDummyBadges);
  });

  it('renders a message if no badges exist', done => {
    store.state.badges = [];

    Vue.nextTick()
      .then(() => {
        expect(vm.$el.innerText).toMatch('This project has no badges');
      })
      .then(done)
      .catch(done.fail);
  });

  it('shows a loading icon when loading', done => {
    store.state.isLoading = true;

    Vue.nextTick()
      .then(() => {
        const loadingIcon = vm.$el.querySelector('.gl-spinner');

        expect(loadingIcon).toBeVisible();
      })
      .then(done)
      .catch(done.fail);
  });

  describe('for group badges', () => {
    beforeEach(done => {
      store.state.kind = GROUP_BADGE;

      Vue.nextTick()
        .then(done)
        .catch(done.fail);
    });

    it('renders a message if no badges exist', done => {
      store.state.badges = [];

      Vue.nextTick()
        .then(() => {
          expect(vm.$el.innerText).toMatch('This group has no badges');
        })
        .then(done)
        .catch(done.fail);
    });
  });
});
