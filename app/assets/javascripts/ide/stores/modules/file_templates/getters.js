import { leftSidebarViews } from '../../../constants';
import { __ } from '~/locale';

export const templateTypes = () => [
  {
    name: '.gitlab-ci.yml',
    key: 'gitlab_ci_ymls',
  },
  {
    name: '.gitignore',
    key: 'gitignores',
  },
  {
    name: __('LICENSE'),
    key: 'licenses',
  },
  {
    name: __('Dockerfile'),
    key: 'dockerfiles',
  },
];

export const showFileTemplatesBar = (_, getters, rootState) => name =>
  getters.templateTypes.find(t => t.name === name) &&
  rootState.currentActivityView === leftSidebarViews.edit.name;

export default () => {};
