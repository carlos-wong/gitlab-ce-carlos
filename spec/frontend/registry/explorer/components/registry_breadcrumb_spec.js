import { shallowMount } from '@vue/test-utils';

import component from '~/registry/explorer/components/registry_breadcrumb.vue';

describe('Registry Breadcrumb', () => {
  let wrapper;
  const nameGenerator = jest.fn();

  const crumb = {
    classList: ['foo', 'bar'],
    tagName: 'div',
    innerHTML: 'baz',
    querySelector: jest.fn(),
    children: [
      {
        tagName: 'a',
        classList: ['foo'],
      },
    ],
  };

  const querySelectorReturnValue = {
    classList: ['js-divider'],
    tagName: 'svg',
    innerHTML: 'foo',
  };

  const crumbs = [crumb, { ...crumb, innerHTML: 'foo' }, { ...crumb, classList: ['baz'] }];

  const routes = [
    { name: 'foo', meta: { nameGenerator, root: true } },
    { name: 'baz', meta: { nameGenerator } },
  ];

  const findDivider = () => wrapper.find('.js-divider');
  const findRootRoute = () => wrapper.find({ ref: 'rootRouteLink' });
  const findChildRoute = () => wrapper.find({ ref: 'childRouteLink' });
  const findLastCrumb = () => wrapper.find({ ref: 'lastCrumb' });

  const mountComponent = $route => {
    wrapper = shallowMount(component, {
      propsData: {
        crumbs,
      },
      stubs: {
        'router-link': { name: 'router-link', template: '<a><slot></slot></a>', props: ['to'] },
      },
      mocks: {
        $route,
        $router: {
          options: {
            routes,
          },
        },
      },
    });
  };

  beforeEach(() => {
    nameGenerator.mockClear();
    crumb.querySelector = jest.fn();
  });

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
  });

  describe('when is rootRoute', () => {
    beforeEach(() => {
      mountComponent(routes[0]);
    });

    it('renders', () => {
      expect(wrapper.element).toMatchSnapshot();
    });

    it('contains a router-link for the child route', () => {
      expect(findChildRoute().exists()).toBe(true);
    });

    it('the link text is calculated by nameGenerator', () => {
      expect(nameGenerator).toHaveBeenCalledWith(routes[0]);
      expect(nameGenerator).toHaveBeenCalledTimes(1);
    });
  });

  describe('when is not rootRoute', () => {
    beforeEach(() => {
      crumb.querySelector.mockReturnValue(querySelectorReturnValue);
      mountComponent(routes[1]);
    });

    it('renders a divider', () => {
      expect(findDivider().exists()).toBe(true);
    });

    it('contains a router-link for the root route', () => {
      expect(findRootRoute().exists()).toBe(true);
    });

    it('contains a router-link for the child route', () => {
      expect(findChildRoute().exists()).toBe(true);
    });

    it('the link text is calculated by nameGenerator', () => {
      expect(nameGenerator).toHaveBeenCalledWith(routes[1]);
      expect(nameGenerator).toHaveBeenCalledTimes(2);
    });
  });

  describe('last crumb', () => {
    const lastChildren = crumb.children[0];
    beforeEach(() => {
      nameGenerator.mockReturnValue('foo');
      mountComponent(routes[0]);
    });

    it('has the same tag as the last children of the crumbs', () => {
      expect(findLastCrumb().is(lastChildren.tagName)).toBe(true);
    });

    it('has the same classes as the last children of the crumbs', () => {
      expect(findLastCrumb().classes()).toEqual(lastChildren.classList);
    });

    it('has a link to the current route', () => {
      expect(findChildRoute().props('to')).toEqual({ to: routes[0].name });
    });

    it('the link has the correct text', () => {
      expect(findChildRoute().text()).toEqual('foo');
    });
  });
});
