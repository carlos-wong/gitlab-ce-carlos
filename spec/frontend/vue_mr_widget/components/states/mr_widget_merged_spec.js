import { getByRole } from '@testing-library/dom';
import Vue, { nextTick } from 'vue';
import mountComponent from 'helpers/vue_mount_component_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { OPEN_REVERT_MODAL, OPEN_CHERRY_PICK_MODAL } from '~/projects/commit/constants';
import modalEventHub from '~/projects/commit/event_hub';
import mergedComponent from '~/vue_merge_request_widget/components/states/mr_widget_merged.vue';
import eventHub from '~/vue_merge_request_widget/event_hub';

describe('MRWidgetMerged', () => {
  let vm;
  const targetBranch = 'foo';
  const selectors = {
    get copyMergeShaButton() {
      return vm.$el.querySelector('button.js-mr-merged-copy-sha');
    },
    get mergeCommitShaLink() {
      return vm.$el.querySelector('a.js-mr-merged-commit-sha');
    },
  };

  beforeEach(() => {
    jest.spyOn(document, 'dispatchEvent');
    const Component = Vue.extend(mergedComponent);
    const mr = {
      isRemovingSourceBranch: false,
      cherryPickInForkPath: false,
      canCherryPickInCurrentMR: true,
      revertInForkPath: false,
      canRevertInCurrentMR: true,
      canRemoveSourceBranch: true,
      sourceBranchRemoved: true,
      metrics: {
        mergedBy: {
          name: 'Administrator',
          username: 'root',
          webUrl: 'http://localhost:3000/root',
          avatarUrl:
            'http://www.gravatar.com/avatar/e64c7d89f26bd1972efa854d13d7dd61?s=80&d=identicon',
        },
        mergedAt: 'Jan 24, 2018 1:02pm UTC',
        readableMergedAt: '',
        closedBy: {},
        closedAt: 'Jan 24, 2018 1:02pm UTC',
        readableClosedAt: '',
      },
      updatedAt: 'mergedUpdatedAt',
      shortMergeCommitSha: '958c0475',
      mergeCommitSha: '958c047516e182dfc52317f721f696e8a1ee85ed',
      mergeCommitPath:
        'http://localhost:3000/root/nautilus/commit/f7ce827c314c9340b075657fd61c789fb01cf74d',
      sourceBranch: 'bar',
      targetBranch,
    };

    const service = {
      removeSourceBranch() {},
    };

    jest.spyOn(eventHub, '$emit').mockImplementation(() => {});

    vm = mountComponent(Component, { mr, service });
  });

  afterEach(() => {
    vm.$destroy();
  });

  describe('computed', () => {
    describe('shouldShowRemoveSourceBranch', () => {
      it('returns true when sourceBranchRemoved is false', () => {
        vm.mr.sourceBranchRemoved = false;

        expect(vm.shouldShowRemoveSourceBranch).toEqual(true);
      });

      it('returns false when sourceBranchRemoved is true', () => {
        vm.mr.sourceBranchRemoved = true;

        expect(vm.shouldShowRemoveSourceBranch).toEqual(false);
      });

      it('returns false when canRemoveSourceBranch is false', () => {
        vm.mr.sourceBranchRemoved = false;
        vm.mr.canRemoveSourceBranch = false;

        expect(vm.shouldShowRemoveSourceBranch).toEqual(false);
      });

      it('returns false when is making request', () => {
        vm.mr.canRemoveSourceBranch = true;
        vm.isMakingRequest = true;

        expect(vm.shouldShowRemoveSourceBranch).toEqual(false);
      });

      it('returns true when all are true', () => {
        vm.mr.isRemovingSourceBranch = true;
        vm.mr.canRemoveSourceBranch = true;
        vm.isMakingRequest = true;

        expect(vm.shouldShowRemoveSourceBranch).toEqual(false);
      });
    });

    describe('shouldShowSourceBranchRemoving', () => {
      it('should correct value when fields changed', () => {
        vm.mr.sourceBranchRemoved = false;

        expect(vm.shouldShowSourceBranchRemoving).toEqual(false);

        vm.mr.sourceBranchRemoved = true;

        expect(vm.shouldShowRemoveSourceBranch).toEqual(false);

        vm.mr.sourceBranchRemoved = false;
        vm.isMakingRequest = true;

        expect(vm.shouldShowSourceBranchRemoving).toEqual(true);

        vm.isMakingRequest = false;
        vm.mr.isRemovingSourceBranch = true;

        expect(vm.shouldShowSourceBranchRemoving).toEqual(true);
      });
    });
  });

  describe('methods', () => {
    describe('removeSourceBranch', () => {
      it('should set flag and call service then request main component to update the widget', async () => {
        jest.spyOn(vm.service, 'removeSourceBranch').mockReturnValue(
          new Promise((resolve) => {
            resolve({
              data: {
                message: 'Branch was deleted',
              },
            });
          }),
        );

        vm.removeSourceBranch();

        await waitForPromises();

        const args = eventHub.$emit.mock.calls[0];

        expect(vm.isMakingRequest).toEqual(true);
        expect(args[0]).toEqual('MRWidgetUpdateRequested');
        expect(args[1]).not.toThrow();
      });
    });
  });

  it('calls dispatchDocumentEvent to load in the modal component', () => {
    expect(document.dispatchEvent).toHaveBeenCalledWith(new CustomEvent('merged:UpdateActions'));
  });

  it('emits event to open the revert modal on revert button click', () => {
    const eventHubSpy = jest.spyOn(modalEventHub, '$emit');

    getByRole(vm.$el, 'button', { name: /Revert/i }).click();

    expect(eventHubSpy).toHaveBeenCalledWith(OPEN_REVERT_MODAL);
  });

  it('emits event to open the cherry-pick modal on cherry-pick button click', () => {
    const eventHubSpy = jest.spyOn(modalEventHub, '$emit');

    getByRole(vm.$el, 'button', { name: /Cherry-pick/i }).click();

    expect(eventHubSpy).toHaveBeenCalledWith(OPEN_CHERRY_PICK_MODAL);
  });

  it('has merged by information', () => {
    expect(vm.$el.textContent).toContain('Merged by');
    expect(vm.$el.textContent).toContain('Administrator');
  });

  it('renders branch information', () => {
    expect(vm.$el.textContent).toContain('The changes were merged into');
    expect(vm.$el.textContent).toContain(targetBranch);
  });

  it('renders information about branch being deleted', () => {
    expect(vm.$el.textContent).toContain('The source branch has been deleted');
  });

  it('shows revert and cherry-pick buttons', () => {
    expect(vm.$el.textContent).toContain('Revert');
    expect(vm.$el.textContent).toContain('Cherry-pick');
  });

  it('shows button to copy commit SHA to clipboard', () => {
    expect(selectors.copyMergeShaButton).not.toBe(null);
    expect(selectors.copyMergeShaButton.getAttribute('data-clipboard-text')).toBe(
      vm.mr.mergeCommitSha,
    );
  });

  it('hides button to copy commit SHA if SHA does not exist', async () => {
    vm.mr.mergeCommitSha = null;

    await nextTick();

    expect(selectors.copyMergeShaButton).toBe(null);
    expect(vm.$el.querySelector('.mr-info-list').innerText).not.toContain('with');
  });

  it('shows merge commit SHA link', () => {
    expect(selectors.mergeCommitShaLink).not.toBe(null);
    expect(selectors.mergeCommitShaLink.text).toContain(vm.mr.shortMergeCommitSha);
    expect(selectors.mergeCommitShaLink.href).toBe(vm.mr.mergeCommitPath);
  });

  it('should not show source branch deleted text', async () => {
    vm.mr.sourceBranchRemoved = false;

    await nextTick();

    expect(vm.$el.innerText).not.toContain('The source branch has been deleted');
  });

  it('should show source branch deleting text', async () => {
    vm.mr.isRemovingSourceBranch = true;
    vm.mr.sourceBranchRemoved = false;

    await nextTick();

    expect(vm.$el.innerText).toContain('The source branch is being deleted');
    expect(vm.$el.innerText).not.toContain('The source branch has been deleted');
  });

  it('should use mergedEvent mergedAt as tooltip title', () => {
    expect(vm.$el.querySelector('time').getAttribute('title')).toBe('Jan 24, 2018 1:02pm UTC');
  });
});
