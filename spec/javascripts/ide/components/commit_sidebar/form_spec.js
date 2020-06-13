import Vue from 'vue';
import { createComponentWithStore } from 'spec/helpers/vue_mount_component_helper';
import getSetTimeoutPromise from 'spec/helpers/set_timeout_promise_helper';
import { projectData } from 'spec/ide/mock_data';
import store from '~/ide/stores';
import CommitForm from '~/ide/components/commit_sidebar/form.vue';
import { leftSidebarViews } from '~/ide/constants';
import { resetStore } from '../../helpers';

describe('IDE commit form', () => {
  const Component = Vue.extend(CommitForm);
  let vm;

  beforeEach(() => {
    spyOnProperty(window, 'innerHeight').and.returnValue(800);

    store.state.changedFiles.push('test');
    store.state.currentProjectId = 'abcproject';
    store.state.currentBranchId = 'master';
    Vue.set(store.state.projects, 'abcproject', { ...projectData });

    vm = createComponentWithStore(Component, store).$mount();
  });

  afterEach(() => {
    vm.$destroy();

    resetStore(vm.$store);
  });

  it('enables button when has changes', () => {
    expect(vm.$el.querySelector('[disabled]')).toBe(null);
  });

  describe('compact', () => {
    beforeEach(done => {
      vm.isCompact = true;

      vm.$nextTick(done);
    });

    it('renders commit button in compact mode', () => {
      expect(vm.$el.querySelector('.btn-primary')).not.toBeNull();
      expect(vm.$el.querySelector('.btn-primary').textContent).toContain('Commit');
    });

    it('does not render form', () => {
      expect(vm.$el.querySelector('form')).toBeNull();
    });

    it('renders overview text', done => {
      vm.$store.state.stagedFiles.push('test');

      vm.$nextTick(() => {
        expect(vm.$el.querySelector('p').textContent).toContain('1 changed file');
        done();
      });
    });

    it('shows form when clicking commit button', done => {
      vm.$el.querySelector('.btn-primary').click();

      vm.$nextTick(() => {
        expect(vm.$el.querySelector('form')).not.toBeNull();

        done();
      });
    });

    it('toggles activity bar view when clicking commit button', done => {
      vm.$el.querySelector('.btn-primary').click();

      vm.$nextTick(() => {
        expect(store.state.currentActivityView).toBe(leftSidebarViews.commit.name);

        done();
      });
    });

    it('collapses if lastCommitMsg is set to empty and current view is not commit view', done => {
      store.state.lastCommitMsg = 'abc';
      store.state.currentActivityView = leftSidebarViews.edit.name;

      vm.$nextTick(() => {
        // if commit message is set, form is uncollapsed
        expect(vm.isCompact).toBe(false);

        store.state.lastCommitMsg = '';

        vm.$nextTick(() => {
          // collapsed when set to empty
          expect(vm.isCompact).toBe(true);

          done();
        });
      });
    });
  });

  describe('full', () => {
    beforeEach(done => {
      vm.isCompact = false;

      vm.$nextTick(done);
    });

    it('updates commitMessage in store on input', done => {
      const textarea = vm.$el.querySelector('textarea');

      textarea.value = 'testing commit message';

      textarea.dispatchEvent(new Event('input'));

      getSetTimeoutPromise()
        .then(() => {
          expect(vm.$store.state.commit.commitMessage).toBe('testing commit message');
        })
        .then(done)
        .catch(done.fail);
    });

    it('updating currentActivityView not to commit view sets compact mode', done => {
      store.state.currentActivityView = 'a';

      vm.$nextTick(() => {
        expect(vm.isCompact).toBe(true);

        done();
      });
    });

    it('always opens itself in full view current activity view is not commit view when clicking commit button', done => {
      vm.$el.querySelector('.btn-primary').click();

      vm.$nextTick(() => {
        expect(store.state.currentActivityView).toBe(leftSidebarViews.commit.name);
        expect(vm.isCompact).toBe(false);

        done();
      });
    });

    describe('discard draft button', () => {
      it('hidden when commitMessage is empty', () => {
        expect(vm.$el.querySelector('.btn-default').textContent).toContain('Collapse');
      });

      it('resets commitMessage when clicking discard button', done => {
        vm.$store.state.commit.commitMessage = 'testing commit message';

        getSetTimeoutPromise()
          .then(() => {
            vm.$el.querySelector('.btn-default').click();
          })
          .then(Vue.nextTick)
          .then(() => {
            expect(vm.$store.state.commit.commitMessage).not.toBe('testing commit message');
          })
          .then(done)
          .catch(done.fail);
      });
    });

    describe('when submitting', () => {
      beforeEach(() => {
        spyOn(vm, 'commitChanges');
        vm.$store.state.stagedFiles.push('test');
      });

      it('calls commitChanges', done => {
        vm.$store.state.commit.commitMessage = 'testing commit message';

        getSetTimeoutPromise()
          .then(() => {
            vm.$el.querySelector('.btn-success').click();
          })
          .then(Vue.nextTick)
          .then(() => {
            expect(vm.commitChanges).toHaveBeenCalled();
          })
          .then(done)
          .catch(done.fail);
      });
    });
  });

  describe('commitButtonText', () => {
    it('returns commit text when staged files exist', () => {
      vm.$store.state.stagedFiles.push('testing');

      expect(vm.commitButtonText).toBe('Commit');
    });

    it('returns stage & commit text when staged files do not exist', () => {
      expect(vm.commitButtonText).toBe('Stage & Commit');
    });
  });
});
