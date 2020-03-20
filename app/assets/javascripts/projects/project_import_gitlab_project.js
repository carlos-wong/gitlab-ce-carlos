import $ from 'jquery';
import { convertToTitleCase, humanize, slugify } from '../lib/utils/text_utility';
import { getParameterValues } from '../lib/utils/url_utility';
import projectNew from './project_new';

const prepareParameters = () => {
  const name = getParameterValues('name')[0];
  const path = getParameterValues('path')[0];

  // If the name param exists but the path doesn't then generate it from the name
  if (name && !path) {
    return { name, path: slugify(name) };
  }

  // If the path param exists but the name doesn't then generate it from the path
  if (path && !name) {
    return { name: convertToTitleCase(humanize(path, '-')), path };
  }

  return { name, path };
};

export default () => {
  let hasUserDefinedProjectName = false;
  const $projectName = $('.js-project-name');
  const $projectPath = $('.js-path-name');
  const { name, path } = prepareParameters();

  // get the project name from the URL and set it as input value
  $projectName.val(name);

  // get the path url and append it in the input
  $projectPath.val(path);

  // generate slug when project name changes
  $projectName.on('keyup', () => {
    projectNew.onProjectNameChange($projectName, $projectPath);
    hasUserDefinedProjectName = $projectName.val().trim().length > 0;
  });

  // generate project name from the slug if one isn't set
  $projectPath.on('keyup', () =>
    projectNew.onProjectPathChange($projectName, $projectPath, hasUserDefinedProjectName),
  );
};
