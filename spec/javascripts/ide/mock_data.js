export const projectData = {
  id: 1,
  name: 'abcproject',
  web_url: '',
  avatar_url: '',
  path: '',
  name_with_namespace: 'namespace/abcproject',
  branches: {
    master: {
      treeId: 'abcproject/master',
      can_push: true,
      commit: {
        id: '123',
      },
    },
  },
  mergeRequests: {},
  merge_requests_enabled: true,
  default_branch: 'master',
};

export const pipelines = [
  {
    id: 1,
    ref: 'master',
    sha: '123',
    details: {
      status: {
        icon: 'status_failed',
        group: 'failed',
        text: 'Failed',
      },
    },
    commit: { id: '123' },
  },
  {
    id: 2,
    ref: 'master',
    sha: '213',
    details: {
      status: {
        icon: 'status_failed',
        group: 'failed',
        text: 'Failed',
      },
    },
    commit: { id: '213' },
  },
];

export const stages = [
  {
    dropdown_path: `${gl.TEST_HOST}/testing`,
    name: 'build',
    status: {
      icon: 'status_failed',
      group: 'failed',
      text: 'failed',
    },
  },
  {
    dropdown_path: 'testing',
    name: 'test',
    status: {
      icon: 'status_failed',
      group: 'failed',
      text: 'failed',
    },
  },
];

export const jobs = [
  {
    id: 1,
    name: 'test',
    path: 'testing',
    status: {
      icon: 'status_success',
      text: 'passed',
    },
    stage: 'test',
    duration: 1,
    started: new Date(),
  },
  {
    id: 2,
    name: 'test 2',
    path: 'testing2',
    status: {
      icon: 'status_success',
      text: 'passed',
    },
    stage: 'test',
    duration: 1,
    started: new Date(),
  },
  {
    id: 3,
    name: 'test 3',
    path: 'testing3',
    status: {
      icon: 'status_success',
      text: 'passed',
    },
    stage: 'test',
    duration: 1,
    started: new Date(),
  },
  {
    id: 4,
    name: 'test 4',
    path: 'testing4',
    status: {
      icon: 'status_failed',
      text: 'failed',
    },
    stage: 'build',
    duration: 1,
    started: new Date(),
  },
];

export const fullPipelinesResponse = {
  data: {
    count: {
      all: 2,
    },
    pipelines: [
      {
        id: '51',
        path: 'test',
        commit: {
          id: '123',
        },
        details: {
          status: {
            icon: 'status_failed',
            text: 'failed',
          },
          stages: [...stages],
        },
      },
      {
        id: '50',
        commit: {
          id: 'abc123def456ghi789jkl',
        },
        details: {
          status: {
            icon: 'status_success',
            text: 'passed',
          },
          stages: [...stages],
        },
      },
    ],
  },
};

export const mergeRequests = [
  {
    id: 1,
    iid: 1,
    title: 'Test merge request',
    project_id: 1,
    web_url: `${gl.TEST_HOST}/namespace/project-path/merge_requests/1`,
  },
];

export const branches = [
  {
    id: 1,
    name: 'master',
    commit: {
      message: 'Update master branch',
      committed_date: '2018-08-01T00:20:05Z',
    },
    can_push: true,
  },
  {
    id: 2,
    name: 'feature/lorem-ipsum',
    commit: {
      message: 'Update some stuff',
      committed_date: '2018-08-02T00:00:05Z',
    },
    can_push: true,
  },
  {
    id: 3,
    name: 'feature/dolar-amit',
    commit: {
      message: 'Update some more stuff',
      committed_date: '2018-06-30T00:20:05Z',
    },
    can_push: true,
  },
];
