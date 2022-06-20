const IS_EE = require('./config/helpers/is_ee_env');
const isESLint = require('./config/helpers/is_eslint');
const IS_JH = require('./config/helpers/is_jh_env');

module.exports = (path, options = {}) => {
  const {
    moduleNameMapper: extModuleNameMapper = {},
    moduleNameMapperEE: extModuleNameMapperEE = {},
    moduleNameMapperJH: extModuleNameMapperJH = {},
  } = options;

  const reporters = ['default'];

  // To have consistent date time parsing both in local and CI environments we set
  // the timezone of the Node process. https://gitlab.com/gitlab-org/gitlab-foss/merge_requests/27738
  process.env.TZ = 'GMT';

  if (process.env.CI) {
    reporters.push([
      'jest-junit',
      {
        outputName: './junit_jest.xml',
        addFileAttribute: 'true',
      },
    ]);
  }

  const glob = `${path}/**/*_spec.js`;
  let testMatch = [`<rootDir>/${glob}`];
  if (IS_EE) {
    testMatch.push(`<rootDir>/ee/${glob}`);
  }

  if (IS_JH) {
    testMatch.push(`<rootDir>/jh/${glob}`);
  }
  // workaround for eslint-import-resolver-jest only resolving in test files
  // see https://github.com/JoinColony/eslint-import-resolver-jest#note
  if (isESLint(module)) {
    testMatch = testMatch.map((modulePath) => modulePath.replace('_spec.js', ''));
  }

  const TEST_FIXTURES_PATTERN = 'test_fixtures(/.*)$';

  const moduleNameMapper = {
    '^~(/.*)$': '<rootDir>/app/assets/javascripts$1',
    '^ee_component(/.*)$':
      '<rootDir>/app/assets/javascripts/vue_shared/components/empty_component.js',
    '^jh_component(/.*)$':
      '<rootDir>/app/assets/javascripts/vue_shared/components/empty_component.js',
    '^shared_queries(/.*)$': '<rootDir>/app/graphql/queries$1',
    '^ee_else_ce(/.*)$': '<rootDir>/app/assets/javascripts$1',
    '^jh_else_ce(/.*)$': '<rootDir>/app/assets/javascripts$1',
    '^any_else_ce(/.*)$': '<rootDir>/app/assets/javascripts$1',
    '^helpers(/.*)$': '<rootDir>/spec/frontend/__helpers__$1',
    '^vendor(/.*)$': '<rootDir>/vendor/assets/javascripts$1',
    [TEST_FIXTURES_PATTERN]: '<rootDir>/tmp/tests/frontend/fixtures$1',
    '^test_fixtures_static(/.*)$': '<rootDir>/spec/frontend/fixtures/static$1',
    '\\.(jpg|jpeg|png|svg|css)$': '<rootDir>/spec/frontend/__mocks__/file_mock.js',
    'emojis(/.*).json': '<rootDir>/fixtures/emojis$1.json',
    '^spec/test_constants$': '<rootDir>/spec/frontend/__helpers__/test_constants',
    '^jest/(.*)$': '<rootDir>/spec/frontend/$1',
    '^jquery$': '<rootDir>/node_modules/jquery/dist/jquery.slim.js',
    ...extModuleNameMapper,
  };

  const collectCoverageFrom = ['<rootDir>/app/assets/javascripts/**/*.{js,vue}'];

  if (IS_EE) {
    const rootDirEE = '<rootDir>/ee/app/assets/javascripts$1';
    Object.assign(moduleNameMapper, {
      '^ee(/.*)$': rootDirEE,
      '^ee_component(/.*)$': rootDirEE,
      '^ee_else_ce(/.*)$': rootDirEE,
      '^ee_jest/(.*)$': '<rootDir>/ee/spec/frontend/$1',
      '^any_else_ce(/.*)$': rootDirEE,
      '^jh_else_ee(/.*)$': rootDirEE,
      [TEST_FIXTURES_PATTERN]: '<rootDir>/tmp/tests/frontend/fixtures-ee$1',
      ...extModuleNameMapperEE,
    });

    collectCoverageFrom.push(rootDirEE.replace('$1', '/**/*.{js,vue}'));
  }

  if (IS_JH) {
    const rootDirJH = '<rootDir>/jh/app/assets/javascripts$1';
    Object.assign(moduleNameMapper, {
      '^jh(/.*)$': rootDirJH,
      '^jh_component(/.*)$': rootDirJH,
      '^jh_jest/(.*)$': '<rootDir>/jh/spec/frontend/$1',
      // jh path alias https://gitlab.com/gitlab-org/gitlab/-/merge_requests/74305#note_732793956
      '^jh_else_ce(/.*)$': rootDirJH,
      '^jh_else_ee(/.*)$': rootDirJH,
      '^any_else_ce(/.*)$': rootDirJH,
      ...extModuleNameMapperJH,
    });

    collectCoverageFrom.push(rootDirJH.replace('$1', '/**/*.{js,vue}'));
  }

  const coverageDirectory = () => {
    if (process.env.CI_NODE_INDEX && process.env.CI_NODE_TOTAL) {
      return `<rootDir>/coverage-frontend/jest-${process.env.CI_NODE_INDEX}-${process.env.CI_NODE_TOTAL}`;
    }

    return '<rootDir>/coverage-frontend/';
  };

  const gfmParserDependencies = [
    'rehype-.*',
    'remark-.*',
    'hast*',
    'unist.*',
    'mdast-util-.*',
    'micromark.*',
    'vfile.*',
    'bail',
    'trough',
    'unified',
    'is-plain-obj',
    'decode-named-character-reference',
    'character-entities*',
    'property-information',
    'space-separated-tokens',
    'comma-separated-tokens',
    'web-namespaces',
    'zwitch',
    'html-void-elements',
    'ccount',
    'escape-string-regexp',
  ];

  const transformIgnoreNodeModules = [
    '@gitlab/ui',
    '@gitlab/favicon-overlay',
    'bootstrap-vue',
    'three',
    'monaco-editor',
    'monaco-yaml',
    'fast-mersenne-twister',
    'prosemirror-markdown',
    'fault',
    'dateformat',
    'lowlight',
    ...gfmParserDependencies,
  ];

  return {
    clearMocks: true,
    testMatch,
    moduleFileExtensions: ['js', 'json', 'vue', 'gql', 'graphql', 'yaml'],
    moduleNameMapper,
    collectCoverageFrom,
    coverageDirectory: coverageDirectory(),
    coverageReporters: ['json', 'lcov', 'text-summary', 'clover'],
    // We need ignore _worker code coverage since we are manually transforming it
    coveragePathIgnorePatterns: ['<rootDir>/node_modules/', '_worker\\.js$'],
    cacheDirectory: '<rootDir>/tmp/cache/jest',
    modulePathIgnorePatterns: ['<rootDir>/.yarn-cache/'],
    reporters,
    resolver: './jest_resolver.js',
    setupFilesAfterEnv: [`<rootDir>/${path}/test_setup.js`, 'jest-canvas-mock'],
    restoreMocks: true,
    transform: {
      '^.+\\.(gql|graphql)$': 'jest-transform-graphql',
      '^.+_worker\\.js$': './spec/frontend/__helpers__/web_worker_transformer.js',
      '^.+\\.js$': 'babel-jest',
      '^.+\\.vue$': 'vue-jest',
      '^.+\\.yml$': './spec/frontend/__helpers__/yaml_transformer.js',
      '^.+\\.(md|zip|png)$': 'jest-raw-loader',
    },
    transformIgnorePatterns: [`node_modules/(?!(${transformIgnoreNodeModules.join('|')}))`],
    timers: 'fake',
    testEnvironment: '<rootDir>/spec/frontend/environment.js',
    testEnvironmentOptions: {
      IS_EE,
      IS_JH,
    },
  };
};
