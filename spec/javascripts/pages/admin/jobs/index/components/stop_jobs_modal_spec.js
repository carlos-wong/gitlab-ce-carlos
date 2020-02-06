import Vue from 'vue';

import mountComponent from 'spec/helpers/vue_mount_component_helper';
import axios from '~/lib/utils/axios_utils';
import stopJobsModal from '~/pages/admin/jobs/index/components/stop_jobs_modal.vue';

describe('stop_jobs_modal.vue', () => {
  const props = {
    url: `${gl.TEST_HOST}/stop_jobs_modal.vue/stopAll`,
  };
  let vm;

  afterEach(() => {
    vm.$destroy();
  });

  beforeEach(() => {
    const Component = Vue.extend(stopJobsModal);
    vm = mountComponent(Component, props);
  });

  describe('onSubmit', () => {
    it('stops jobs and redirects to overview page', done => {
      const responseURL = `${gl.TEST_HOST}/stop_jobs_modal.vue/jobs`;
      const redirectSpy = spyOnDependency(stopJobsModal, 'redirectTo');
      spyOn(axios, 'post').and.callFake(url => {
        expect(url).toBe(props.url);
        return Promise.resolve({
          request: {
            responseURL,
          },
        });
      });

      vm.onSubmit()
        .then(() => {
          expect(redirectSpy).toHaveBeenCalledWith(responseURL);
        })
        .then(done)
        .catch(done.fail);
    });

    it('displays error if stopping jobs failed', done => {
      const dummyError = new Error('stopping jobs failed');
      const redirectSpy = spyOnDependency(stopJobsModal, 'redirectTo');
      spyOn(axios, 'post').and.callFake(url => {
        expect(url).toBe(props.url);
        return Promise.reject(dummyError);
      });

      vm.onSubmit()
        .then(done.fail)
        .catch(error => {
          expect(error).toBe(dummyError);
          expect(redirectSpy).not.toHaveBeenCalled();
        })
        .then(done)
        .catch(done.fail);
    });
  });
});
