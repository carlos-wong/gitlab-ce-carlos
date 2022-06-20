import { nextTick } from 'vue';
import { GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import createFlash from '~/flash';
import Approvals from '~/vue_merge_request_widget/components/approvals/approvals.vue';
import ApprovalsSummary from '~/vue_merge_request_widget/components/approvals/approvals_summary.vue';
import ApprovalsSummaryOptional from '~/vue_merge_request_widget/components/approvals/approvals_summary_optional.vue';
import {
  FETCH_LOADING,
  FETCH_ERROR,
  APPROVE_ERROR,
  UNAPPROVE_ERROR,
} from '~/vue_merge_request_widget/components/approvals/messages';
import eventHub from '~/vue_merge_request_widget/event_hub';

jest.mock('~/flash');

const TEST_HELP_PATH = 'help/path';
const testApprovedBy = () => [1, 7, 10].map((id) => ({ id }));
const testApprovals = () => ({
  approved: false,
  approved_by: testApprovedBy().map((user) => ({ user })),
  approval_rules_left: [],
  approvals_left: 4,
  suggested_approvers: [],
  user_can_approve: true,
  user_has_approved: true,
  require_password_to_approve: false,
});
const testApprovalRulesResponse = () => ({ rules: [{ id: 2 }] });

describe('MRWidget approvals', () => {
  let wrapper;
  let service;
  let mr;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(Approvals, {
      propsData: {
        mr,
        service,
        ...props,
      },
    });
  };

  const findAction = () => wrapper.find(GlButton);
  const findActionData = () => {
    const action = findAction();

    return !action.exists()
      ? null
      : {
          variant: action.props('variant'),
          category: action.props('category'),
          text: action.text(),
        };
  };
  const findSummary = () => wrapper.find(ApprovalsSummary);
  const findOptionalSummary = () => wrapper.find(ApprovalsSummaryOptional);

  beforeEach(() => {
    service = {
      ...{
        fetchApprovals: jest.fn().mockReturnValue(Promise.resolve(testApprovals())),
        fetchApprovalSettings: jest
          .fn()
          .mockReturnValue(Promise.resolve(testApprovalRulesResponse())),
        approveMergeRequest: jest.fn().mockReturnValue(Promise.resolve(testApprovals())),
        unapproveMergeRequest: jest.fn().mockReturnValue(Promise.resolve(testApprovals())),
        approveMergeRequestWithAuth: jest.fn().mockReturnValue(Promise.resolve(testApprovals())),
      },
    };
    mr = {
      ...{
        setApprovals: jest.fn(),
        setApprovalRules: jest.fn(),
      },
      approvalsHelpPath: TEST_HELP_PATH,
      approvals: testApprovals(),
      approvalRules: [],
      isOpen: true,
      state: 'open',
    };

    jest.spyOn(eventHub, '$emit').mockImplementation(() => {});
  });

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
  });

  describe('when created', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows loading message', () => {
      // setData usage is discouraged. See https://gitlab.com/groups/gitlab-org/-/epics/7330 for details
      // eslint-disable-next-line no-restricted-syntax
      wrapper.setData({ fetchingApprovals: true });

      return nextTick().then(() => {
        expect(wrapper.text()).toContain(FETCH_LOADING);
      });
    });

    it('fetches approvals', () => {
      expect(service.fetchApprovals).toHaveBeenCalled();
    });
  });

  describe('when fetch approvals error', () => {
    beforeEach(() => {
      jest.spyOn(service, 'fetchApprovals').mockReturnValue(Promise.reject());
      createComponent();
      return nextTick();
    });

    it('still shows loading message', () => {
      expect(wrapper.text()).toContain(FETCH_LOADING);
    });

    it('flashes error', () => {
      expect(createFlash).toHaveBeenCalledWith({ message: FETCH_ERROR });
    });
  });

  describe('action button', () => {
    describe('when mr is closed', () => {
      beforeEach(() => {
        mr.isOpen = false;
        mr.approvals.user_has_approved = false;
        mr.approvals.user_can_approve = true;

        createComponent();
        return nextTick();
      });

      it('action is not rendered', () => {
        expect(findActionData()).toBe(null);
      });
    });

    describe('when user cannot approve', () => {
      beforeEach(() => {
        mr.approvals.user_has_approved = false;
        mr.approvals.user_can_approve = false;

        createComponent();
        return nextTick();
      });

      it('action is not rendered', () => {
        expect(findActionData()).toBe(null);
      });
    });

    describe('when user can approve', () => {
      beforeEach(() => {
        mr.approvals.user_has_approved = false;
        mr.approvals.user_can_approve = true;
      });

      describe('and MR is unapproved', () => {
        beforeEach(() => {
          createComponent();
          return nextTick();
        });

        it('approve action is rendered', () => {
          expect(findActionData()).toEqual({
            variant: 'info',
            text: 'Approve',
            category: 'primary',
          });
        });
      });

      describe('and MR is approved', () => {
        beforeEach(() => {
          mr.approvals.approved = true;
        });

        describe('with no approvers', () => {
          beforeEach(() => {
            mr.approvals.approved_by = [];
            createComponent();
            return nextTick();
          });

          it('approve action (with inverted style) is rendered', () => {
            expect(findActionData()).toEqual({
              variant: 'info',
              text: 'Approve',
              category: 'secondary',
            });
          });
        });

        describe('with approvers', () => {
          beforeEach(() => {
            mr.approvals.approved_by = [{ user: { id: 7 } }];
            createComponent();
            return nextTick();
          });

          it('approve additionally action is rendered', () => {
            expect(findActionData()).toEqual({
              variant: 'info',
              text: 'Approve additionally',
              category: 'secondary',
            });
          });
        });
      });

      describe('when approve action is clicked', () => {
        beforeEach(() => {
          createComponent();
          return nextTick();
        });

        it('shows loading icon', () => {
          jest.spyOn(service, 'approveMergeRequest').mockReturnValue(new Promise(() => {}));
          const action = findAction();

          expect(action.props('loading')).toBe(false);

          action.vm.$emit('click');

          return nextTick().then(() => {
            expect(action.props('loading')).toBe(true);
          });
        });

        describe('and after loading', () => {
          beforeEach(() => {
            findAction().vm.$emit('click');
            return nextTick();
          });

          it('calls service approve', () => {
            expect(service.approveMergeRequest).toHaveBeenCalled();
          });

          it('emits to eventHub', () => {
            expect(eventHub.$emit).toHaveBeenCalledWith('MRWidgetUpdateRequested');
          });

          it('calls store setApprovals', () => {
            expect(mr.setApprovals).toHaveBeenCalledWith(testApprovals());
          });
        });

        describe('and error', () => {
          beforeEach(() => {
            jest.spyOn(service, 'approveMergeRequest').mockReturnValue(Promise.reject());
            findAction().vm.$emit('click');
            return nextTick();
          });

          it('flashes error message', () => {
            expect(createFlash).toHaveBeenCalledWith({ message: APPROVE_ERROR });
          });
        });
      });
    });

    describe('when user has approved', () => {
      beforeEach(() => {
        mr.approvals.user_has_approved = true;
        mr.approvals.user_can_approve = false;

        createComponent();
        return nextTick();
      });

      it('revoke action is rendered', () => {
        expect(findActionData()).toEqual({
          variant: 'warning',
          text: 'Revoke approval',
          category: 'secondary',
        });
      });

      describe('when revoke action is clicked', () => {
        describe('and successful', () => {
          beforeEach(() => {
            findAction().vm.$emit('click');
            return nextTick();
          });

          it('calls service unapprove', () => {
            expect(service.unapproveMergeRequest).toHaveBeenCalled();
          });

          it('emits to eventHub', () => {
            expect(eventHub.$emit).toHaveBeenCalledWith('MRWidgetUpdateRequested');
          });

          it('calls store setApprovals', () => {
            expect(mr.setApprovals).toHaveBeenCalledWith(testApprovals());
          });
        });

        describe('and error', () => {
          beforeEach(() => {
            jest.spyOn(service, 'unapproveMergeRequest').mockReturnValue(Promise.reject());
            findAction().vm.$emit('click');
            return nextTick();
          });

          it('flashes error message', () => {
            expect(createFlash).toHaveBeenCalledWith({ message: UNAPPROVE_ERROR });
          });
        });
      });
    });
  });

  describe('approvals optional summary', () => {
    describe('when no approvals required and no approvers', () => {
      beforeEach(() => {
        mr.approvals.approved_by = [];
        mr.approvals.approvals_required = 0;
        mr.approvals.user_has_approved = false;
      });

      describe('and can approve', () => {
        beforeEach(() => {
          mr.approvals.user_can_approve = true;

          createComponent();
          return nextTick();
        });

        it('is shown', () => {
          expect(findSummary().exists()).toBe(false);
          expect(findOptionalSummary().props()).toEqual({
            canApprove: true,
            helpPath: TEST_HELP_PATH,
          });
        });
      });

      describe('and cannot approve', () => {
        beforeEach(() => {
          mr.approvals.user_can_approve = false;

          createComponent();
          return nextTick();
        });

        it('is shown', () => {
          expect(findSummary().exists()).toBe(false);
          expect(findOptionalSummary().props()).toEqual({
            canApprove: false,
            helpPath: TEST_HELP_PATH,
          });
        });
      });
    });
  });

  describe('approvals summary', () => {
    beforeEach(() => {
      createComponent();
      return nextTick();
    });

    it('is rendered with props', () => {
      const expected = testApprovals();
      const summary = findSummary();

      expect(findOptionalSummary().exists()).toBe(false);
      expect(summary.exists()).toBe(true);
      expect(summary.props()).toMatchObject({
        approvalsLeft: expected.approvals_left,
        rulesLeft: expected.approval_rules_left,
        approvers: testApprovedBy(),
      });
    });
  });
});
