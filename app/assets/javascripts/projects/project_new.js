import $ from 'jquery';
import { addSelectOnFocusBehaviour } from '../lib/utils/common_utils';
import { convertToTitleCase, humanize, slugify } from '../lib/utils/text_utility';
import { s__ } from '~/locale';

let hasUserDefinedProjectPath = false;
let hasUserDefinedProjectName = false;

const onProjectNameChange = ($projectNameInput, $projectPathInput) => {
  const slug = slugify($projectNameInput.val());
  $projectPathInput.val(slug);
};

const onProjectPathChange = ($projectNameInput, $projectPathInput, hasExistingProjectName) => {
  const slug = $projectPathInput.val();

  if (!hasExistingProjectName) {
    $projectNameInput.val(convertToTitleCase(humanize(slug, '[-_]')));
  }
};

const setProjectNamePathHandlers = ($projectNameInput, $projectPathInput) => {
  $projectNameInput.off('keyup change').on('keyup change', () => {
    onProjectNameChange($projectNameInput, $projectPathInput);
    hasUserDefinedProjectName = $projectNameInput.val().trim().length > 0;
    hasUserDefinedProjectPath = $projectPathInput.val().trim().length > 0;
  });

  $projectPathInput.off('keyup change').on('keyup change', () => {
    onProjectPathChange($projectNameInput, $projectPathInput, hasUserDefinedProjectName);
    hasUserDefinedProjectPath = $projectPathInput.val().trim().length > 0;
  });
};

const deriveProjectPathFromUrl = $projectImportUrl => {
  const $currentProjectName = $projectImportUrl
    .parents('.toggle-import-form')
    .find('#project_name');
  const $currentProjectPath = $projectImportUrl
    .parents('.toggle-import-form')
    .find('#project_path');

  if (hasUserDefinedProjectPath) {
    return;
  }

  let importUrl = $projectImportUrl.val().trim();
  if (importUrl.length === 0) {
    return;
  }

  /*
    \/?: remove trailing slash
    (\.git\/?)?: remove trailing .git (with optional trailing slash)
    (\?.*)?: remove query string
    (#.*)?: remove fragment identifier
  */
  importUrl = importUrl.replace(/\/?(\.git\/?)?(\?.*)?(#.*)?$/, '');

  // extract everything after the last slash
  const pathMatch = /\/([^/]+)$/.exec(importUrl);
  if (pathMatch) {
    $currentProjectPath.val(pathMatch[1]);
    onProjectPathChange($currentProjectName, $currentProjectPath, false);
  }
};

const bindEvents = () => {
  const $newProjectForm = $('#new_project');
  const $projectImportUrl = $('#project_import_url');
  const $projectPath = $('.tab-pane.active #project_path');
  const $useTemplateBtn = $('.template-button > input');
  const $projectFieldsForm = $('.project-fields-form');
  const $selectedTemplateText = $('.selected-template');
  const $changeTemplateBtn = $('.change-template');
  const $selectedIcon = $('.selected-icon');
  const $pushNewProjectTipTrigger = $('.push-new-project-tip');
  const $projectTemplateButtons = $('.project-templates-buttons');
  const $projectName = $('.tab-pane.active #project_name');

  if ($newProjectForm.length !== 1) {
    return;
  }

  $('.how_to_import_link').on('click', e => {
    e.preventDefault();
    $(e.currentTarget)
      .next('.modal')
      .show();
  });

  $('.modal-header .close').on('click', () => {
    $('.modal').hide();
  });

  $('.btn_import_gitlab_project').on('click', () => {
    const importHref = $('a.btn_import_gitlab_project').attr('href');
    $('.btn_import_gitlab_project').attr(
      'href',
      `${importHref}?namespace_id=${$(
        '#project_namespace_id',
      ).val()}&name=${$projectName.val()}&path=${$projectPath.val()}`,
    );
  });

  if ($pushNewProjectTipTrigger) {
    $pushNewProjectTipTrigger
      .removeAttr('rel')
      .removeAttr('target')
      .on('click', e => {
        e.preventDefault();
      })
      .popover({
        title: $pushNewProjectTipTrigger.data('title'),
        placement: 'bottom',
        html: true,
        content: $('.push-new-project-tip-template').html(),
      })
      .on('shown.bs.popover', () => {
        $(document).on('click.popover touchstart.popover', event => {
          if ($(event.target).closest('.popover').length === 0) {
            $pushNewProjectTipTrigger.trigger('click');
          }
        });

        const target = $(`#${$pushNewProjectTipTrigger.attr('aria-describedby')}`).find(
          '.js-select-on-focus',
        );
        addSelectOnFocusBehaviour(target);

        target.focus();
      })
      .on('hide.bs.popover', () => {
        $(document).off('click.popover touchstart.popover');
      });
  }

  function chooseTemplate() {
    $projectTemplateButtons.addClass('hidden');
    $projectFieldsForm.addClass('selected');
    $selectedIcon.empty();
    const value = $(this).val();
    const templates = {
      rails: {
        text: s__('ProjectTemplates|Ruby on Rails'),
        icon: '.template-option .icon-rails',
      },
      express: {
        text: s__('ProjectTemplates|NodeJS Express'),
        icon: '.template-option .icon-express',
      },
      spring: {
        text: s__('ProjectTemplates|Spring'),
        icon: '.template-option .icon-spring',
      },
      iosswift: {
        text: s__('ProjectTemplates|iOS (Swift)'),
        icon: '.template-option .icon-iosswift',
      },
      dotnetcore: {
        text: s__('ProjectTemplates|.NET Core'),
        icon: '.template-option .icon-dotnetcore',
      },
      android: {
        text: s__('ProjectTemplates|Android'),
        icon: '.template-option .icon-android',
      },
      gomicro: {
        text: s__('ProjectTemplates|Go Micro'),
        icon: '.template-option .icon-gomicro',
      },
      hugo: {
        text: s__('ProjectTemplates|Pages/Hugo'),
        icon: '.template-option .icon-hugo',
      },
      jekyll: {
        text: s__('ProjectTemplates|Pages/Jekyll'),
        icon: '.template-option .icon-jekyll',
      },
      plainhtml: {
        text: s__('ProjectTemplates|Pages/Plain HTML'),
        icon: '.template-option .icon-plainhtml',
      },
      gitbook: {
        text: s__('ProjectTemplates|Pages/GitBook'),
        icon: '.template-option .icon-gitbook',
      },
      hexo: {
        text: s__('ProjectTemplates|Pages/Hexo'),
        icon: '.template-option .icon-hexo',
      },
      nfhugo: {
        text: s__('ProjectTemplates|Netlify/Hugo'),
        icon: '.template-option .icon-nfhugo',
      },
      nfjekyll: {
        text: s__('ProjectTemplates|Netlify/Jekyll'),
        icon: '.template-option .icon-nfjekyll',
      },
      nfplainhtml: {
        text: s__('ProjectTemplates|Netlify/Plain HTML'),
        icon: '.template-option .icon-nfplainhtml',
      },
      nfgitbook: {
        text: s__('ProjectTemplates|Netlify/GitBook'),
        icon: '.template-option .icon-nfgitbook',
      },
      nfhexo: {
        text: s__('ProjectTemplates|Netlify/Hexo'),
        icon: '.template-option .icon-nfhexo',
      },
      salesforcedx: {
        text: s__('ProjectTemplates|SalesforceDX'),
        icon: '.template-option .icon-salesforcedx',
      },
      serverless_framework: {
        text: s__('ProjectTemplates|Serverless Framework/JS'),
        icon: '.template-option .icon-serverless_framework',
      },
    };

    const selectedTemplate = templates[value];
    $selectedTemplateText.text(selectedTemplate.text);
    $(selectedTemplate.icon)
      .clone()
      .addClass('d-block')
      .appendTo($selectedIcon);

    const $activeTabProjectName = $('.tab-pane.active #project_name');
    const $activeTabProjectPath = $('.tab-pane.active #project_path');
    $activeTabProjectName.focus();
    setProjectNamePathHandlers($activeTabProjectName, $activeTabProjectPath);
  }

  $useTemplateBtn.on('change', chooseTemplate);

  $changeTemplateBtn.on('click', () => {
    $projectTemplateButtons.removeClass('hidden');
    $projectFieldsForm.removeClass('selected');
    $useTemplateBtn.prop('checked', false);
  });

  $newProjectForm.on('submit', () => {
    $projectPath.val($projectPath.val().trim());
  });

  $projectImportUrl.keyup(() => deriveProjectPathFromUrl($projectImportUrl));

  $('.js-import-git-toggle-button').on('click', () => {
    const $projectMirror = $('#project_mirror');

    $projectMirror.attr('disabled', !$projectMirror.attr('disabled'));
    setProjectNamePathHandlers(
      $('.tab-pane.active #project_name'),
      $('.tab-pane.active #project_path'),
    );
  });

  setProjectNamePathHandlers($projectName, $projectPath);
};

export default {
  bindEvents,
  deriveProjectPathFromUrl,
  onProjectNameChange,
  onProjectPathChange,
};
