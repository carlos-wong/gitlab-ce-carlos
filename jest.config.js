const IS_EE = require('./config/helpers/is_ee_env');

const reporters = ['default'];

// To have consistent date time parsing both in local and CI environments we set
// the timezone of the Node process. https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/27738
process.env.TZ = 'GMT';

if (process.env.CI) {
  reporters.push([
    'jest-junit',
    {
      output: './junit_jest.xml',
    },
  ]);
}

// eslint-disable-next-line import/no-commonjs
module.exports = {
  testMatch: ['<rootDir>/spec/frontend/**/*_spec.js', '<rootDir>/ee/spec/frontend/**/*_spec.js'],
  moduleFileExtensions: ['js', 'json', 'vue'],
  moduleNameMapper: {
    '^~(/.*)$': '<rootDir>/app/assets/javascripts$1',
    '^ee(/.*)$': '<rootDir>/ee/app/assets/javascripts$1',
    '^ee_else_ce(/.*)$': IS_EE
      ? '<rootDir>/ee/app/assets/javascripts$1'
      : '<rootDir>/app/assets/javascripts$1',
    '^helpers(/.*)$': '<rootDir>/spec/frontend/helpers$1',
    '^vendor(/.*)$': '<rootDir>/vendor/assets/javascripts$1',
    '\\.(jpg|jpeg|png|svg)$': '<rootDir>/spec/frontend/__mocks__/file_mock.js',
    'emojis(/.*).json': '<rootDir>/fixtures/emojis$1.json',
  },
  collectCoverageFrom: ['<rootDir>/app/assets/javascripts/**/*.{js,vue}'],
  coverageDirectory: '<rootDir>/coverage-frontend/',
  coverageReporters: ['json', 'lcov', 'text-summary', 'clover'],
  cacheDirectory: '<rootDir>/tmp/cache/jest',
  modulePathIgnorePatterns: ['<rootDir>/.yarn-cache/'],
  reporters,
  setupFilesAfterEnv: ['<rootDir>/spec/frontend/test_setup.js'],
  restoreMocks: true,
  transform: {
    '^.+\\.(gql|graphql)$': 'jest-transform-graphql',
    '^.+\\.js$': 'babel-jest',
    '^.+\\.vue$': 'vue-jest',
  },
  transformIgnorePatterns: ['node_modules/(?!(@gitlab/ui)/)'],
  timers: 'fake',
  testEnvironment: '<rootDir>/spec/frontend/environment.js',
  testEnvironmentOptions: {
    IS_EE,
  },
};
