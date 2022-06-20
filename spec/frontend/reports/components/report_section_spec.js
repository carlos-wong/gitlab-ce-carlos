import { mount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import mountComponent, { mountComponentWithSlots } from 'helpers/vue_mount_component_helper';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import HelpPopover from '~/vue_shared/components/help_popover.vue';
import reportSection from '~/reports/components/report_section.vue';

describe('Report section', () => {
  let vm;
  let wrapper;
  const ReportSection = Vue.extend(reportSection);
  const findCollapseButton = () => wrapper.findByTestId('report-section-expand-button');
  const findPopover = () => wrapper.findComponent(HelpPopover);

  const resolvedIssues = [
    {
      name: 'Insecure Dependency',
      fingerprint: 'ca2e59451e98ae60ba2f54e3857c50e5',
      path: 'Gemfile.lock',
      line: 12,
      urlPath: 'foo/Gemfile.lock',
    },
  ];

  const defaultProps = {
    component: '',
    status: 'SUCCESS',
    loadingText: 'Loading Code Quality report',
    errorText: 'foo',
    successText: 'Code quality improved on 1 point and degraded on 1 point',
    resolvedIssues,
    hasIssues: false,
    alwaysOpen: false,
  };

  const createComponent = (props) => {
    wrapper = extendedWrapper(
      mount(reportSection, {
        propsData: {
          ...defaultProps,
          ...props,
        },
      }),
    );
    return wrapper;
  };

  afterEach(() => {
    if (vm) {
      vm.$destroy();
      vm = null;
    }
    if (wrapper) {
      wrapper.destroy();
      wrapper = null;
    }
  });

  describe('computed', () => {
    beforeEach(() => {
      vm = mountComponent(ReportSection, defaultProps);
    });

    describe('isCollapsible', () => {
      const testMatrix = [
        { hasIssues: false, alwaysOpen: false, isCollapsible: false },
        { hasIssues: false, alwaysOpen: true, isCollapsible: false },
        { hasIssues: true, alwaysOpen: false, isCollapsible: true },
        { hasIssues: true, alwaysOpen: true, isCollapsible: false },
      ];

      testMatrix.forEach(({ hasIssues, alwaysOpen, isCollapsible }) => {
        const issues = hasIssues ? 'has issues' : 'has no issues';
        const open = alwaysOpen ? 'is always open' : 'is not always open';

        it(`is ${isCollapsible}, if the report ${issues} and ${open}`, async () => {
          vm.hasIssues = hasIssues;
          vm.alwaysOpen = alwaysOpen;

          await nextTick();
          expect(vm.isCollapsible).toBe(isCollapsible);
        });
      });
    });

    describe('isExpanded', () => {
      const testMatrix = [
        { isCollapsed: false, alwaysOpen: false, isExpanded: true },
        { isCollapsed: false, alwaysOpen: true, isExpanded: true },
        { isCollapsed: true, alwaysOpen: false, isExpanded: false },
        { isCollapsed: true, alwaysOpen: true, isExpanded: true },
      ];

      testMatrix.forEach(({ isCollapsed, alwaysOpen, isExpanded }) => {
        const issues = isCollapsed ? 'is collapsed' : 'is not collapsed';
        const open = alwaysOpen ? 'is always open' : 'is not always open';

        it(`is ${isExpanded}, if the report ${issues} and ${open}`, async () => {
          vm.isCollapsed = isCollapsed;
          vm.alwaysOpen = alwaysOpen;

          await nextTick();
          expect(vm.isExpanded).toBe(isExpanded);
        });
      });
    });
  });

  describe('when it is loading', () => {
    it('should render loading indicator', () => {
      vm = mountComponent(ReportSection, {
        component: '',
        status: 'LOADING',
        loadingText: 'Loading Code Quality report',
        errorText: 'foo',
        successText: 'Code quality improved on 1 point and degraded on 1 point',
        hasIssues: false,
      });

      expect(vm.$el.textContent.trim()).toEqual('Loading Code Quality report');
    });
  });

  describe('with success status', () => {
    beforeEach(() => {
      vm = mountComponent(ReportSection, {
        ...defaultProps,
        hasIssues: true,
      });
    });

    it('should render provided data', () => {
      expect(vm.$el.querySelector('.js-code-text').textContent.trim()).toEqual(
        'Code quality improved on 1 point and degraded on 1 point',
      );

      expect(vm.$el.querySelectorAll('.report-block-container li').length).toEqual(
        resolvedIssues.length,
      );
    });

    describe('toggleCollapsed', () => {
      const hiddenCss = { display: 'none' };

      it('toggles issues', async () => {
        vm.$el.querySelector('button').click();

        await nextTick();
        expect(vm.$el.querySelector('.js-report-section-container')).not.toHaveCss(hiddenCss);
        expect(vm.$el.querySelector('button').textContent.trim()).toEqual('Collapse');

        vm.$el.querySelector('button').click();

        await nextTick();
        expect(vm.$el.querySelector('.js-report-section-container')).toHaveCss(hiddenCss);
        expect(vm.$el.querySelector('button').textContent.trim()).toEqual('Expand');
      });

      it('is always expanded, if always-open is set to true', async () => {
        vm.alwaysOpen = true;
        await nextTick();
        expect(vm.$el.querySelector('.js-report-section-container')).not.toHaveCss(hiddenCss);
        expect(vm.$el.querySelector('button')).toBeNull();
      });
    });
  });

  describe('snowplow events', () => {
    it('does emit an event on issue toggle if the shouldEmitToggleEvent prop does exist', async () => {
      createComponent({ hasIssues: true, shouldEmitToggleEvent: true });

      expect(wrapper.emitted().toggleEvent).toBeUndefined();

      findCollapseButton().trigger('click');
      await nextTick();
      expect(wrapper.emitted().toggleEvent).toHaveLength(1);
    });

    it('does not emit an event on issue toggle if the shouldEmitToggleEvent prop does not exist', async () => {
      createComponent({ hasIssues: true });

      expect(wrapper.emitted().toggleEvent).toBeUndefined();

      findCollapseButton().trigger('click');
      await nextTick();
      expect(wrapper.emitted().toggleEvent).toBeUndefined();
    });

    it('does not emit an event if always-open is set to true', async () => {
      createComponent({ alwaysOpen: true, hasIssues: true, shouldEmitToggleEvent: true });

      await nextTick();
      expect(wrapper.emitted().toggleEvent).toBeUndefined();
    });
  });

  describe('with failed request', () => {
    it('should render error indicator', () => {
      vm = mountComponent(ReportSection, {
        component: '',
        status: 'ERROR',
        loadingText: 'Loading Code Quality report',
        errorText: 'Failed to load Code Quality report',
        successText: 'Code quality improved on 1 point and degraded on 1 point',
        hasIssues: false,
      });

      expect(vm.$el.textContent.trim()).toEqual('Failed to load Code Quality report');
    });
  });

  describe('with action buttons passed to the slot', () => {
    beforeEach(() => {
      vm = mountComponentWithSlots(ReportSection, {
        props: {
          status: 'SUCCESS',
          successText: 'success',
          hasIssues: true,
        },
        slots: {
          'action-buttons': ['Action!'],
        },
      });
    });

    it('should render the passed button', () => {
      expect(vm.$el.textContent.trim()).toContain('Action!');
    });

    it('should still render the expand/collapse button', () => {
      expect(vm.$el.querySelector('.js-collapse-btn').textContent.trim()).toEqual('Expand');
    });
  });

  describe('Success and Error slots', () => {
    const createComponentWithSlots = (status) => {
      vm = mountComponentWithSlots(ReportSection, {
        props: {
          status,
          hasIssues: true,
        },
        slots: {
          success: ['This is a success'],
          loading: ['This is loading'],
          error: ['This is an error'],
        },
      });
    };

    it('only renders success slot when status is "SUCCESS"', () => {
      createComponentWithSlots('SUCCESS');

      expect(vm.$el.textContent.trim()).toContain('This is a success');
      expect(vm.$el.textContent.trim()).not.toContain('This is an error');
      expect(vm.$el.textContent.trim()).not.toContain('This is loading');
    });

    it('only renders error slot when status is "ERROR"', () => {
      createComponentWithSlots('ERROR');

      expect(vm.$el.textContent.trim()).toContain('This is an error');
      expect(vm.$el.textContent.trim()).not.toContain('This is a success');
      expect(vm.$el.textContent.trim()).not.toContain('This is loading');
    });

    it('only renders loading slot when status is "LOADING"', () => {
      createComponentWithSlots('LOADING');

      expect(vm.$el.textContent.trim()).toContain('This is loading');
      expect(vm.$el.textContent.trim()).not.toContain('This is an error');
      expect(vm.$el.textContent.trim()).not.toContain('This is a success');
    });
  });

  describe('help popover', () => {
    describe('when popover options are defined', () => {
      const options = {
        title: 'foo',
        content: 'bar',
      };

      beforeEach(() => {
        createComponent({
          popoverOptions: options,
        });
      });

      it('popover is shown with options', () => {
        expect(findPopover().props('options')).toEqual(options);
      });
    });

    describe('when popover options are not defined', () => {
      beforeEach(() => {
        createComponent({ popoverOptions: {} });
      });

      it('popover is not shown', () => {
        expect(findPopover().exists()).toBe(false);
      });
    });
  });
});
