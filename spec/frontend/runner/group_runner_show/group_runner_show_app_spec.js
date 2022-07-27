import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert, VARIANT_SUCCESS } from '~/flash';
import { redirectTo } from '~/lib/utils/url_utility';

import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import RunnerHeader from '~/runner/components/runner_header.vue';
import RunnerDetails from '~/runner/components/runner_details.vue';
import RunnerPauseButton from '~/runner/components/runner_pause_button.vue';
import RunnerDeleteButton from '~/runner/components/runner_delete_button.vue';
import RunnerEditButton from '~/runner/components/runner_edit_button.vue';
import runnerQuery from '~/runner/graphql/show/runner.query.graphql';
import GroupRunnerShowApp from '~/runner/group_runner_show/group_runner_show_app.vue';
import { captureException } from '~/runner/sentry_utils';
import { saveAlertToLocalStorage } from '~/runner/local_storage_alert/save_alert_to_local_storage';

import { runnerData } from '../mock_data';

jest.mock('~/runner/local_storage_alert/save_alert_to_local_storage');
jest.mock('~/flash');
jest.mock('~/runner/sentry_utils');
jest.mock('~/lib/utils/url_utility');

const mockRunner = runnerData.data.runner;
const mockRunnerGraphqlId = mockRunner.id;
const mockRunnerId = `${getIdFromGraphQLId(mockRunnerGraphqlId)}`;
const mockRunnersPath = '/groups/group1/-/runners';
const mockEditGroupRunnerPath = `/groups/group1/-/runners/${mockRunnerId}/edit`;

Vue.use(VueApollo);

describe('GroupRunnerShowApp', () => {
  let wrapper;
  let mockRunnerQuery;

  const findRunnerHeader = () => wrapper.findComponent(RunnerHeader);
  const findRunnerDetails = () => wrapper.findComponent(RunnerDetails);
  const findRunnerDeleteButton = () => wrapper.findComponent(RunnerDeleteButton);
  const findRunnerEditButton = () => wrapper.findComponent(RunnerEditButton);
  const findRunnerPauseButton = () => wrapper.findComponent(RunnerPauseButton);

  const mockRunnerQueryResult = (runner = {}) => {
    mockRunnerQuery = jest.fn().mockResolvedValue({
      data: {
        runner: { ...mockRunner, ...runner },
      },
    });
  };

  const createComponent = ({ props = {}, mountFn = shallowMountExtended, ...options } = {}) => {
    wrapper = mountFn(GroupRunnerShowApp, {
      apolloProvider: createMockApollo([[runnerQuery, mockRunnerQuery]]),
      propsData: {
        runnerId: mockRunnerId,
        runnersPath: mockRunnersPath,
        editGroupRunnerPath: mockEditGroupRunnerPath,
        ...props,
      },
      ...options,
    });

    return waitForPromises();
  };

  afterEach(() => {
    mockRunnerQuery.mockReset();
    wrapper.destroy();
  });

  describe('When showing runner details', () => {
    beforeEach(async () => {
      mockRunnerQueryResult();

      await createComponent({ mountFn: mountExtended });
    });

    it('expect GraphQL ID to be requested', async () => {
      expect(mockRunnerQuery).toHaveBeenCalledWith({ id: mockRunnerGraphqlId });
    });

    it('displays the header', async () => {
      expect(findRunnerHeader().text()).toContain(`Runner #${mockRunnerId}`);
    });

    it('displays edit, pause, delete buttons', async () => {
      expect(findRunnerEditButton().exists()).toBe(true);
      expect(findRunnerPauseButton().exists()).toBe(true);
      expect(findRunnerDeleteButton().exists()).toBe(true);
    });

    it('shows basic runner details', () => {
      const expected = `Description Instance runner
                        Last contact Never contacted
                        Version 1.0.0
                        IP Address 127.0.0.1
                        Executor None
                        Architecture None
                        Platform darwin
                        Configuration Runs untagged jobs
                        Maximum job timeout None
                        Tags None`.replace(/\s+/g, ' ');

      expect(wrapper.text().replace(/\s+/g, ' ')).toContain(expected);
    });

    it('renders runner details component', () => {
      expect(findRunnerDetails().props('runner')).toEqual(mockRunner);
    });

    describe('when runner cannot be updated', () => {
      beforeEach(async () => {
        mockRunnerQueryResult({
          userPermissions: {
            ...mockRunner.userPermissions,
            updateRunner: false,
          },
        });

        await createComponent({
          mountFn: mountExtended,
        });
      });

      it('does not display edit and pause buttons', () => {
        expect(findRunnerEditButton().exists()).toBe(false);
        expect(findRunnerPauseButton().exists()).toBe(false);
      });

      it('displays delete button', () => {
        expect(findRunnerDeleteButton().exists()).toBe(true);
      });
    });

    describe('when runner cannot be deleted', () => {
      beforeEach(async () => {
        mockRunnerQueryResult({
          userPermissions: {
            ...mockRunner.userPermissions,
            deleteRunner: false,
          },
        });

        await createComponent({
          mountFn: mountExtended,
        });
      });

      it('does not display delete button', () => {
        expect(findRunnerDeleteButton().exists()).toBe(false);
      });

      it('displays edit and pause buttons', () => {
        expect(findRunnerEditButton().exists()).toBe(true);
        expect(findRunnerPauseButton().exists()).toBe(true);
      });
    });

    describe('when runner is deleted', () => {
      beforeEach(async () => {
        await createComponent({
          mountFn: mountExtended,
        });
      });

      it('redirects to the runner list page', () => {
        findRunnerDeleteButton().vm.$emit('deleted', { message: 'Runner deleted' });

        expect(saveAlertToLocalStorage).toHaveBeenCalledWith({
          message: 'Runner deleted',
          variant: VARIANT_SUCCESS,
        });
        expect(redirectTo).toHaveBeenCalledWith(mockRunnersPath);
      });
    });
  });

  describe('When loading', () => {
    beforeEach(() => {
      mockRunnerQueryResult();

      createComponent();
    });

    it('does not show runner details', () => {
      expect(findRunnerDetails().exists()).toBe(false);
    });
  });

  describe('When there is an error', () => {
    beforeEach(async () => {
      mockRunnerQuery = jest.fn().mockRejectedValueOnce(new Error('Error!'));
      await createComponent();
    });

    it('does not show runner details', () => {
      expect(findRunnerDetails().exists()).toBe(false);
    });

    it('error is reported to sentry', () => {
      expect(captureException).toHaveBeenCalledWith({
        error: new Error('Error!'),
        component: 'GroupRunnerShowApp',
      });
    });

    it('error is shown to the user', () => {
      expect(createAlert).toHaveBeenCalled();
    });
  });
});
