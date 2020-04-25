import Vue from 'vue';
import _ from 'lodash';
import { createComponentWithStore } from 'spec/helpers/vue_mount_component_helper';
import { TEST_HOST } from 'spec/test_constants';
import { createStore } from '~/ide/stores';
import IdeStatusBar from '~/ide/components/ide_status_bar.vue';
import { rightSidebarViews } from '~/ide/constants';
import { projectData } from '../mock_data';

const TEST_PROJECT_ID = 'abcproject';
const TEST_MERGE_REQUEST_ID = '9001';
const TEST_MERGE_REQUEST_URL = `${TEST_HOST}merge-requests/${TEST_MERGE_REQUEST_ID}`;

describe('ideStatusBar', () => {
  let store;
  let vm;

  const createComponent = () => {
    vm = createComponentWithStore(Vue.extend(IdeStatusBar), store).$mount();
  };
  const findMRStatus = () => vm.$el.querySelector('.js-ide-status-mr');

  beforeEach(() => {
    store = createStore();
    store.state.currentProjectId = TEST_PROJECT_ID;
    store.state.projects[TEST_PROJECT_ID] = _.clone(projectData);
    store.state.currentBranchId = 'master';
  });

  afterEach(() => {
    vm.$destroy();
  });

  describe('default', () => {
    beforeEach(() => {
      createComponent();
    });

    it('triggers a setInterval', () => {
      expect(vm.intervalId).not.toBe(null);
    });

    it('renders the statusbar', () => {
      expect(vm.$el.className).toBe('ide-status-bar');
    });

    describe('commitAgeUpdate', () => {
      beforeEach(function() {
        jasmine.clock().install();
        spyOn(vm, 'commitAgeUpdate').and.callFake(() => {});
        vm.startTimer();
      });

      afterEach(function() {
        jasmine.clock().uninstall();
      });

      it('gets called every second', () => {
        expect(vm.commitAgeUpdate).not.toHaveBeenCalled();

        jasmine.clock().tick(1100);

        expect(vm.commitAgeUpdate.calls.count()).toEqual(1);

        jasmine.clock().tick(1000);

        expect(vm.commitAgeUpdate.calls.count()).toEqual(2);
      });
    });

    describe('getCommitPath', () => {
      it('returns the path to the commit details', () => {
        expect(vm.getCommitPath('abc123de')).toBe('/commit/abc123de');
      });
    });

    describe('pipeline status', () => {
      it('opens right sidebar on clicking icon', done => {
        spyOn(vm, 'openRightPane');
        Vue.set(vm.$store.state.pipelines, 'latestPipeline', {
          details: {
            status: {
              text: 'success',
              details_path: 'test',
              icon: 'status_success',
            },
          },
          commit: {
            author_gravatar_url: 'www',
          },
        });

        vm.$nextTick()
          .then(() => {
            vm.$el.querySelector('.ide-status-pipeline button').click();

            expect(vm.openRightPane).toHaveBeenCalledWith(rightSidebarViews.pipelines);
          })
          .then(done)
          .catch(done.fail);
      });
    });

    it('does not show merge request status', () => {
      expect(findMRStatus()).toBe(null);
    });
  });

  describe('with merge request in store', () => {
    beforeEach(() => {
      store.state.projects[TEST_PROJECT_ID].mergeRequests = {
        [TEST_MERGE_REQUEST_ID]: {
          web_url: TEST_MERGE_REQUEST_URL,
          references: {
            short: `!${TEST_MERGE_REQUEST_ID}`,
          },
        },
      };
      store.state.currentMergeRequestId = TEST_MERGE_REQUEST_ID;

      createComponent();
    });

    it('shows merge request status', () => {
      expect(findMRStatus().textContent.trim()).toEqual(`Merge request !${TEST_MERGE_REQUEST_ID}`);
      expect(findMRStatus().querySelector('a').href).toEqual(TEST_MERGE_REQUEST_URL);
    });
  });
});
