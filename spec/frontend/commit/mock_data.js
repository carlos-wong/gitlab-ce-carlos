export const mockStages = [
  {
    name: 'build',
    title: 'build: passed',
    status: {
      icon: 'status_success',
      text: 'passed',
      label: 'passed',
      group: 'success',
      tooltip: 'passed',
      has_details: true,
      details_path: '/root/ci-project/-/pipelines/611#build',
      illustration: null,
      favicon:
        '/assets/ci_favicons/favicon_status_success-8451333011eee8ce9f2ab25dc487fe24a8758c694827a582f17f42b0a90446a2.png',
    },
    path: '/root/ci-project/-/pipelines/611#build',
    dropdown_path: '/root/ci-project/-/pipelines/611/stage.json?stage=build',
  },
  {
    name: 'test',
    title: 'test: passed',
    status: {
      icon: 'status_success',
      text: 'passed',
      label: 'passed',
      group: 'success',
      tooltip: 'passed',
      has_details: true,
      details_path: '/root/ci-project/-/pipelines/611#test',
      illustration: null,
      favicon:
        '/assets/ci_favicons/favicon_status_success-8451333011eee8ce9f2ab25dc487fe24a8758c694827a582f17f42b0a90446a2.png',
    },
    path: '/root/ci-project/-/pipelines/611#test',
    dropdown_path: '/root/ci-project/-/pipelines/611/stage.json?stage=test',
  },
  {
    name: 'test_two',
    title: 'test_two: passed',
    status: {
      icon: 'status_success',
      text: 'passed',
      label: 'passed',
      group: 'success',
      tooltip: 'passed',
      has_details: true,
      details_path: '/root/ci-project/-/pipelines/611#test_two',
      illustration: null,
      favicon:
        '/assets/ci_favicons/favicon_status_success-8451333011eee8ce9f2ab25dc487fe24a8758c694827a582f17f42b0a90446a2.png',
    },
    path: '/root/ci-project/-/pipelines/611#test_two',
    dropdown_path: '/root/ci-project/-/pipelines/611/stage.json?stage=test_two',
  },
  {
    name: 'manual',
    title: 'manual: skipped',
    status: {
      icon: 'status_skipped',
      text: 'skipped',
      label: 'skipped',
      group: 'skipped',
      tooltip: 'skipped',
      has_details: true,
      details_path: '/root/ci-project/-/pipelines/611#manual',
      illustration: null,
      favicon:
        '/assets/ci_favicons/favicon_status_skipped-0b9c5e543588945e8c4ca57786bbf2d0c56631959c9f853300392d0315be829b.png',
      action: {
        icon: 'play',
        title: 'Play all manual',
        path: '/root/ci-project/-/pipelines/611/stages/manual/play_manual',
        method: 'post',
        button_title: 'Play all manual',
      },
    },
    path: '/root/ci-project/-/pipelines/611#manual',
    dropdown_path: '/root/ci-project/-/pipelines/611/stage.json?stage=manual',
  },
  {
    name: 'deploy',
    title: 'deploy: passed',
    status: {
      icon: 'status_success',
      text: 'passed',
      label: 'passed',
      group: 'success',
      tooltip: 'passed',
      has_details: true,
      details_path: '/root/ci-project/-/pipelines/611#deploy',
      illustration: null,
      favicon:
        '/assets/ci_favicons/favicon_status_success-8451333011eee8ce9f2ab25dc487fe24a8758c694827a582f17f42b0a90446a2.png',
    },
    path: '/root/ci-project/-/pipelines/611#deploy',
    dropdown_path: '/root/ci-project/-/pipelines/611/stage.json?stage=deploy',
  },
  {
    name: 'qa',
    title: 'qa: passed',
    status: {
      icon: 'status_success',
      text: 'passed',
      label: 'passed',
      group: 'success',
      tooltip: 'passed',
      has_details: true,
      details_path: '/root/ci-project/-/pipelines/611#qa',
      illustration: null,
      favicon:
        '/assets/ci_favicons/favicon_status_success-8451333011eee8ce9f2ab25dc487fe24a8758c694827a582f17f42b0a90446a2.png',
    },
    path: '/root/ci-project/-/pipelines/611#qa',
    dropdown_path: '/root/ci-project/-/pipelines/611/stage.json?stage=qa',
  },
];

export const mockPipelineStagesQueryResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/20',
      pipeline: {
        id: 'gid://gitlab/Ci::Pipeline/320',
        stages: {
          nodes: [
            {
              __typename: 'CiStage',
              id: 'gid://gitlab/Ci::Stage/409',
              name: 'build',
              detailedStatus: {
                id: 'success-409-409',
                group: 'success',
                icon: 'status_success',
                __typename: 'DetailedStatus',
              },
            },
          ],
        },
      },
    },
  },
};

export const mockPipelineStatusResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/20',
      pipeline: {
        id: 'gid://gitlab/Ci::Pipeline/320',
        detailedStatus: {
          id: 'pending-320-320',
          detailsPath: '/root/ci-project/-/pipelines/320',
          icon: 'status_pending',
          group: 'pending',
          __typename: 'DetailedStatus',
        },
        __typename: 'Pipeline',
      },
      __typename: 'Project',
    },
  },
};
