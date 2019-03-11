/* eslint-disable import/no-commonjs, filenames/match-regex */

const BABEL_ENV = process.env.BABEL_ENV || process.env.NODE_ENV || null;

const presets = [
  [
    '@babel/preset-env',
    {
      modules: false,
      targets: {
        ie: '11',
      },
    },
  ],
];

// include stage 3 proposals
const plugins = [
  '@babel/plugin-syntax-dynamic-import',
  '@babel/plugin-syntax-import-meta',
  '@babel/plugin-proposal-class-properties',
  '@babel/plugin-proposal-json-strings',
  '@babel/plugin-proposal-private-methods',
];

// add code coverage tooling if necessary
if (BABEL_ENV === 'coverage') {
  plugins.push([
    'babel-plugin-istanbul',
    {
      exclude: ['spec/javascripts/**/*', 'app/assets/javascripts/locale/**/app.js'],
    },
  ]);
}

// add rewire support when running tests
if (BABEL_ENV === 'karma' || BABEL_ENV === 'coverage') {
  plugins.push('babel-plugin-rewire');
}

// Jest is running in node environment
if (BABEL_ENV === 'jest') {
  plugins.push('@babel/plugin-transform-modules-commonjs');
  /*
  without the following, babel-plugin-istanbul throws an error:
  https://gitlab.com/gitlab-org/gitlab-ce/issues/58390
  */
  plugins.push('babel-plugin-dynamic-import-node');
}

module.exports = { presets, plugins };
