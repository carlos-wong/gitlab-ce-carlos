import { GlBadge } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import RunnerStatusBadge from '~/runner/components/runner_status_badge.vue';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import {
  STATUS_ONLINE,
  STATUS_OFFLINE,
  STATUS_STALE,
  STATUS_NEVER_CONTACTED,
  I18N_NEVER_CONTACTED_TOOLTIP,
  I18N_STALE_NEVER_CONTACTED_TOOLTIP,
} from '~/runner/constants';

describe('RunnerTypeBadge', () => {
  let wrapper;

  const findBadge = () => wrapper.findComponent(GlBadge);
  const getTooltip = () => getBinding(findBadge().element, 'gl-tooltip');

  const createComponent = (props = {}) => {
    wrapper = shallowMount(RunnerStatusBadge, {
      propsData: {
        runner: {
          contactedAt: '2020-12-31T23:59:00Z',
          status: STATUS_ONLINE,
        },
        ...props,
      },
      directives: {
        GlTooltip: createMockDirective(),
      },
    });
  };

  beforeEach(() => {
    jest.useFakeTimers('modern');
    jest.setSystemTime(new Date('2021-01-01T00:00:00Z'));
  });

  afterEach(() => {
    jest.useFakeTimers('legacy');

    wrapper.destroy();
  });

  it('renders online state', () => {
    createComponent();

    expect(wrapper.text()).toBe('online');
    expect(findBadge().props('variant')).toBe('success');
    expect(getTooltip().value).toBe('Runner is online; last contact was 1 minute ago');
  });

  it('renders never contacted state', () => {
    createComponent({
      runner: {
        contactedAt: null,
        status: STATUS_NEVER_CONTACTED,
      },
    });

    expect(wrapper.text()).toBe('never contacted');
    expect(findBadge().props('variant')).toBe('muted');
    expect(getTooltip().value).toBe(I18N_NEVER_CONTACTED_TOOLTIP);
  });

  it('renders offline state', () => {
    createComponent({
      runner: {
        contactedAt: '2020-12-31T00:00:00Z',
        status: STATUS_OFFLINE,
      },
    });

    expect(wrapper.text()).toBe('offline');
    expect(findBadge().props('variant')).toBe('muted');
    expect(getTooltip().value).toBe('Runner is offline; last contact was 1 day ago');
  });

  it('renders stale state', () => {
    createComponent({
      runner: {
        contactedAt: '2020-01-01T00:00:00Z',
        status: STATUS_STALE,
      },
    });

    expect(wrapper.text()).toBe('stale');
    expect(findBadge().props('variant')).toBe('warning');
    expect(getTooltip().value).toBe('Runner is stale; last contact was 1 year ago');
  });

  it('renders stale state with no contact time', () => {
    createComponent({
      runner: {
        contactedAt: null,
        status: STATUS_STALE,
      },
    });

    expect(wrapper.text()).toBe('stale');
    expect(findBadge().props('variant')).toBe('warning');
    expect(getTooltip().value).toBe(I18N_STALE_NEVER_CONTACTED_TOOLTIP);
  });

  describe('does not fail when data is missing', () => {
    it('contacted_at is missing', () => {
      createComponent({
        runner: {
          contactedAt: null,
          status: STATUS_ONLINE,
        },
      });

      expect(wrapper.text()).toBe('online');
      expect(getTooltip().value).toBe('Runner is online; last contact was never');
    });

    it('status is missing', () => {
      createComponent({
        runner: {
          status: null,
        },
      });

      expect(wrapper.text()).toBe('');
    });
  });
});
