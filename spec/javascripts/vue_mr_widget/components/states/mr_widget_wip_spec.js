import Vue from 'vue';
import WorkInProgress from '~/vue_merge_request_widget/components/states/work_in_progress.vue';
import eventHub from '~/vue_merge_request_widget/event_hub';

const createComponent = () => {
  const Component = Vue.extend(WorkInProgress);
  const mr = {
    title: 'The best MR ever',
    removeWIPPath: '/path/to/remove/wip',
  };
  const service = {
    removeWIP() {},
  };
  return new Component({
    el: document.createElement('div'),
    propsData: { mr, service },
  });
};

describe('Wip', () => {
  describe('props', () => {
    it('should have props', () => {
      const { mr, service } = WorkInProgress.props;

      expect(mr.type instanceof Object).toBeTruthy();
      expect(mr.required).toBeTruthy();

      expect(service.type instanceof Object).toBeTruthy();
      expect(service.required).toBeTruthy();
    });
  });

  describe('data', () => {
    it('should have default data', () => {
      const vm = createComponent();

      expect(vm.isMakingRequest).toBeFalsy();
    });
  });

  describe('methods', () => {
    const mrObj = {
      is_new_mr_data: true,
    };

    describe('handleRemoveWIP', () => {
      it('should make a request to service and handle response', done => {
        const vm = createComponent();

        const flashSpy = spyOnDependency(WorkInProgress, 'createFlash').and.returnValue(true);
        spyOn(eventHub, '$emit');
        spyOn(vm.service, 'removeWIP').and.returnValue(
          new Promise(resolve => {
            resolve({
              data: mrObj,
            });
          }),
        );

        vm.handleRemoveWIP();
        setTimeout(() => {
          expect(vm.isMakingRequest).toBeTruthy();
          expect(eventHub.$emit).toHaveBeenCalledWith('UpdateWidgetData', mrObj);
          expect(flashSpy).toHaveBeenCalledWith('The merge request can now be merged.', 'notice');
          done();
        }, 333);
      });
    });
  });

  describe('template', () => {
    let vm;
    let el;

    beforeEach(() => {
      vm = createComponent();
      el = vm.$el;
    });

    it('should have correct elements', () => {
      expect(el.classList.contains('mr-widget-body')).toBeTruthy();
      expect(el.innerText).toContain('This is a Work in Progress');
      expect(el.querySelector('button').getAttribute('disabled')).toBeTruthy();
      expect(el.querySelector('button').innerText).toContain('Merge');
      expect(el.querySelector('.js-remove-wip').innerText.replace(/\s\s+/g, ' ')).toContain(
        'Resolve WIP status',
      );
    });

    it('should not show removeWIP button is user cannot update MR', done => {
      vm.mr.removeWIPPath = '';

      Vue.nextTick(() => {
        expect(el.querySelector('.js-remove-wip')).toEqual(null);
        done();
      });
    });
  });
});
