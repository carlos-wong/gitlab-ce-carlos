import { GlDeprecatedSkeletonLoading as GlSkeletonLoading } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/flash';
import RunnerJobs from '~/runner/components/runner_jobs.vue';
import RunnerJobsTable from '~/runner/components/runner_jobs_table.vue';
import RunnerPagination from '~/runner/components/runner_pagination.vue';
import { captureException } from '~/runner/sentry_utils';
import { I18N_NO_JOBS_FOUND, RUNNER_DETAILS_JOBS_PAGE_SIZE } from '~/runner/constants';

import runnerJobsQuery from '~/runner/graphql/details/runner_jobs.query.graphql';

import { runnerData, runnerJobsData } from '../mock_data';

jest.mock('~/flash');
jest.mock('~/runner/sentry_utils');

const mockRunner = runnerData.data.runner;
const mockRunnerWithJobs = runnerJobsData.data.runner;
const mockJobs = mockRunnerWithJobs.jobs.nodes;

Vue.use(VueApollo);

describe('RunnerJobs', () => {
  let wrapper;
  let mockRunnerJobsQuery;

  const findGlSkeletonLoading = () => wrapper.findComponent(GlSkeletonLoading);
  const findRunnerJobsTable = () => wrapper.findComponent(RunnerJobsTable);
  const findRunnerPagination = () => wrapper.findComponent(RunnerPagination);

  const createComponent = ({ mountFn = shallowMountExtended } = {}) => {
    wrapper = mountFn(RunnerJobs, {
      apolloProvider: createMockApollo([[runnerJobsQuery, mockRunnerJobsQuery]]),
      propsData: {
        runner: mockRunner,
      },
    });
  };

  beforeEach(() => {
    mockRunnerJobsQuery = jest.fn();
  });

  afterEach(() => {
    mockRunnerJobsQuery.mockReset();
    wrapper.destroy();
  });

  it('Requests runner jobs', async () => {
    createComponent();

    await waitForPromises();

    expect(mockRunnerJobsQuery).toHaveBeenCalledTimes(1);
    expect(mockRunnerJobsQuery).toHaveBeenCalledWith({
      id: mockRunner.id,
      first: RUNNER_DETAILS_JOBS_PAGE_SIZE,
    });
  });

  describe('When there are jobs assigned', () => {
    beforeEach(async () => {
      mockRunnerJobsQuery.mockResolvedValueOnce(runnerJobsData);

      createComponent();
      await waitForPromises();
    });

    it('Shows jobs', () => {
      const jobs = findRunnerJobsTable().props('jobs');

      expect(jobs).toHaveLength(mockJobs.length);
      expect(jobs[0]).toMatchObject(mockJobs[0]);
    });

    describe('When "Next" page is clicked', () => {
      beforeEach(async () => {
        findRunnerPagination().vm.$emit('input', { page: 2, after: 'AFTER_CURSOR' });

        await waitForPromises();
      });

      it('A new page is requested', () => {
        expect(mockRunnerJobsQuery).toHaveBeenCalledTimes(2);
        expect(mockRunnerJobsQuery).toHaveBeenLastCalledWith({
          id: mockRunner.id,
          first: RUNNER_DETAILS_JOBS_PAGE_SIZE,
          after: 'AFTER_CURSOR',
        });
      });
    });
  });

  describe('When loading', () => {
    it('shows loading indicator and no other content', () => {
      createComponent();

      expect(findGlSkeletonLoading().exists()).toBe(true);
      expect(findRunnerJobsTable().exists()).toBe(false);
      expect(findRunnerPagination().attributes('disabled')).toBe('true');
    });
  });

  describe('When there are no jobs', () => {
    beforeEach(async () => {
      mockRunnerJobsQuery.mockResolvedValueOnce({
        data: {
          runner: {
            id: mockRunner.id,
            projectCount: 0,
            jobs: {
              nodes: [],
              pageInfo: {
                hasNextPage: false,
                hasPreviousPage: false,
                startCursor: '',
                endCursor: '',
              },
            },
          },
        },
      });

      createComponent();
      await waitForPromises();
    });

    it('Shows a "None" label', () => {
      expect(wrapper.text()).toBe(I18N_NO_JOBS_FOUND);
    });
  });

  describe('When an error occurs', () => {
    beforeEach(async () => {
      mockRunnerJobsQuery.mockRejectedValue(new Error('Error!'));

      createComponent();
      await waitForPromises();
    });

    it('shows an error', () => {
      expect(createAlert).toHaveBeenCalled();
    });

    it('reports an error', () => {
      expect(captureException).toHaveBeenCalledWith({
        component: 'RunnerJobs',
        error: expect.any(Error),
      });
    });
  });
});
