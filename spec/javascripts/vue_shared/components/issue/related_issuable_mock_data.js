export const defaultProps = {
  endpoint: '/foo/bar/issues/1/related_issues',
  currentNamespacePath: 'foo',
  currentProjectPath: 'bar',
};

export const issuable1 = {
  id: 200,
  epic_issue_id: 1,
  confidential: false,
  reference: 'foo/bar#123',
  displayReference: '#123',
  title: 'some title',
  path: '/foo/bar/issues/123',
  state: 'opened',
};

export const issuable2 = {
  id: 201,
  epic_issue_id: 2,
  confidential: false,
  reference: 'foo/bar#124',
  displayReference: '#124',
  title: 'some other thing',
  path: '/foo/bar/issues/124',
  state: 'opened',
};

export const issuable3 = {
  id: 202,
  epic_issue_id: 3,
  confidential: false,
  reference: 'foo/bar#125',
  displayReference: '#125',
  title: 'some other other thing',
  path: '/foo/bar/issues/125',
  state: 'opened',
};

export const issuable4 = {
  id: 203,
  epic_issue_id: 4,
  confidential: false,
  reference: 'foo/bar#126',
  displayReference: '#126',
  title: 'some other other other thing',
  path: '/foo/bar/issues/126',
  state: 'opened',
};

export const issuable5 = {
  id: 204,
  epic_issue_id: 5,
  confidential: false,
  reference: 'foo/bar#127',
  displayReference: '#127',
  title: 'some other other other thing',
  path: '/foo/bar/issues/127',
  state: 'opened',
};

export const defaultMilestone = {
  id: 1,
  state: 'active',
  title: 'Milestone title',
  start_date: '2018-01-01',
  due_date: '2019-12-31',
};

export const defaultAssignees = [
  {
    id: 1,
    name: 'Administrator',
    username: 'root',
    state: 'active',
    avatar_url: `${gl.TEST_HOST}`,
    web_url: `${gl.TEST_HOST}/root`,
    status_tooltip_html: null,
    path: '/root',
  },
  {
    id: 13,
    name: 'Brooks Beatty',
    username: 'brynn_champlin',
    state: 'active',
    avatar_url: `${gl.TEST_HOST}`,
    web_url: `${gl.TEST_HOST}/brynn_champlin`,
    status_tooltip_html: null,
    path: '/brynn_champlin',
  },
  {
    id: 6,
    name: 'Bryce Turcotte',
    username: 'melynda',
    state: 'active',
    avatar_url: `${gl.TEST_HOST}`,
    web_url: `${gl.TEST_HOST}/melynda`,
    status_tooltip_html: null,
    path: '/melynda',
  },
  {
    id: 20,
    name: 'Conchita Eichmann',
    username: 'juliana_gulgowski',
    state: 'active',
    avatar_url: `${gl.TEST_HOST}`,
    web_url: `${gl.TEST_HOST}/juliana_gulgowski`,
    status_tooltip_html: null,
    path: '/juliana_gulgowski',
  },
];
