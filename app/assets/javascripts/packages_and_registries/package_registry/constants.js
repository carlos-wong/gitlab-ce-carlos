import { s__, __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

export {
  DELETE_PACKAGE_TRACKING_ACTION,
  REQUEST_DELETE_PACKAGE_TRACKING_ACTION,
  CANCEL_DELETE_PACKAGE_TRACKING_ACTION,
  PULL_PACKAGE_TRACKING_ACTION,
  DELETE_PACKAGE_FILE_TRACKING_ACTION,
  REQUEST_DELETE_PACKAGE_FILE_TRACKING_ACTION,
  CANCEL_DELETE_PACKAGE_FILE_TRACKING_ACTION,
  DOWNLOAD_PACKAGE_ASSET_TRACKING_ACTION,
} from '~/packages_and_registries/shared/constants';

export const PACKAGE_TYPE_CONAN = 'CONAN';
export const PACKAGE_TYPE_MAVEN = 'MAVEN';
export const PACKAGE_TYPE_NPM = 'NPM';
export const PACKAGE_TYPE_NUGET = 'NUGET';
export const PACKAGE_TYPE_PYPI = 'PYPI';
export const PACKAGE_TYPE_COMPOSER = 'COMPOSER';
export const PACKAGE_TYPE_RUBYGEMS = 'RUBYGEMS';
export const PACKAGE_TYPE_GENERIC = 'GENERIC';
export const PACKAGE_TYPE_DEBIAN = 'DEBIAN';
export const PACKAGE_TYPE_HELM = 'HELM';

export const TRACKING_LABEL_CODE_INSTRUCTION = 'code_instruction';
export const TRACKING_LABEL_CONAN_INSTALLATION = 'conan_installation';
export const TRACKING_LABEL_MAVEN_INSTALLATION = 'maven_installation';
export const TRACKING_LABEL_NPM_INSTALLATION = 'npm_installation';
export const TRACKING_LABEL_NUGET_INSTALLATION = 'nuget_installation';
export const TRACKING_LABEL_PYPI_INSTALLATION = 'pypi_installation';
export const TRACKING_LABEL_COMPOSER_INSTALLATION = 'composer_installation';

export const TRACKING_ACTION_INSTALLATION = 'installation';
export const TRACKING_ACTION_REGISTRY_SETUP = 'registry_setup';

export const TRACKING_ACTION_COPY_CONAN_COMMAND = 'copy_conan_command';
export const TRACKING_ACTION_COPY_CONAN_SETUP_COMMAND = 'copy_conan_setup_command';

export const TRACKING_ACTION_COPY_MAVEN_XML = 'copy_maven_xml';
export const TRACKING_ACTION_COPY_MAVEN_COMMAND = 'copy_maven_command';
export const TRACKING_ACTION_COPY_MAVEN_SETUP = 'copy_maven_setup_xml';
export const TRACKING_ACTION_COPY_GRADLE_INSTALL_COMMAND = 'copy_gradle_install_command';
export const TRACKING_ACTION_COPY_GRADLE_ADD_TO_SOURCE_COMMAND =
  'copy_gradle_add_to_source_command';
export const TRACKING_ACTION_COPY_KOTLIN_INSTALL_COMMAND = 'copy_kotlin_install_command';
export const TRACKING_ACTION_COPY_KOTLIN_ADD_TO_SOURCE_COMMAND =
  'copy_kotlin_add_to_source_command';

export const TRACKING_ACTION_COPY_NPM_INSTALL_COMMAND = 'copy_npm_install_command';
export const TRACKING_ACTION_COPY_NPM_SETUP_COMMAND = 'copy_npm_setup_command';
export const TRACKING_ACTION_COPY_YARN_INSTALL_COMMAND = 'copy_yarn_install_command';
export const TRACKING_ACTION_COPY_YARN_SETUP_COMMAND = 'copy_yarn_setup_command';

export const TRACKING_ACTION_COPY_NUGET_INSTALL_COMMAND = 'copy_nuget_install_command';
export const TRACKING_ACTION_COPY_NUGET_SETUP_COMMAND = 'copy_nuget_setup_command';

export const TRACKING_ACTION_COPY_PIP_INSTALL_COMMAND = 'copy_pip_install_command';
export const TRACKING_ACTION_COPY_PYPI_SETUP_COMMAND = 'copy_pypi_setup_command';

export const TRACKING_ACTION_COPY_COMPOSER_REGISTRY_INCLUDE_COMMAND =
  'copy_composer_registry_include_command';
export const TRACKING_ACTION_COPY_COMPOSER_PACKAGE_INCLUDE_COMMAND =
  'copy_composer_package_include_command';

export const TRACKING_LABEL_PACKAGE_ASSET = 'package_assets';

export const TRACKING_ACTION_DOWNLOAD_PACKAGE_ASSET = 'download_package_asset';
export const TRACKING_ACTION_EXPAND_PACKAGE_ASSET = 'expand_package_asset';
export const TRACKING_ACTION_COPY_PACKAGE_ASSET_SHA = 'copy_package_asset_sha';

export const SHOW_DELETE_SUCCESS_ALERT = 'showSuccessDeleteAlert';
export const DELETE_PACKAGE_FILE_ERROR_MESSAGE = s__(
  'PackageRegistry|Something went wrong while deleting the package file.',
);
export const DELETE_PACKAGE_FILE_SUCCESS_MESSAGE = s__(
  'PackageRegistry|Package file deleted successfully',
);
export const FETCH_PACKAGE_DETAILS_ERROR_MESSAGE = s__(
  'PackageRegistry|Failed to load the package data',
);
export const FETCH_PACKAGE_PIPELINES_ERROR_MESSAGE = s__(
  'PackageRegistry|Something went wrong while fetching the package history.',
);
export const FETCH_PACKAGE_METADATA_ERROR_MESSAGE = s__(
  'PackageRegistry|Something went wrong while fetching the package metadata.',
);

export const DELETE_PACKAGE_SUCCESS_MESSAGE = s__('PackageRegistry|Package deleted successfully');
export const PACKAGE_REGISTRY_TITLE = __('Package Registry');

export const PACKAGE_ERROR_STATUS = 'ERROR';
export const PACKAGE_DEFAULT_STATUS = 'DEFAULT';
export const PACKAGE_HIDDEN_STATUS = 'HIDDEN';
export const PACKAGE_PROCESSING_STATUS = 'PROCESSING';

export const NPM_PACKAGE_MANAGER = 'npm';
export const YARN_PACKAGE_MANAGER = 'yarn';

export const PROJECT_PACKAGE_ENDPOINT_TYPE = 'project';
export const INSTANCE_PACKAGE_ENDPOINT_TYPE = 'instance';

export const PROJECT_RESOURCE_TYPE = 'project';
export const GROUP_RESOURCE_TYPE = 'group';
export const GRAPHQL_PAGE_SIZE = 20;

export const LIST_KEY_NAME = 'name';
export const LIST_KEY_PROJECT = 'project_path';
export const LIST_KEY_VERSION = 'version';
export const LIST_KEY_PACKAGE_TYPE = 'type';
export const LIST_KEY_CREATED_AT = 'created_at';

export const LIST_LABEL_NAME = __('Name');
export const LIST_LABEL_PROJECT = __('Project');
export const LIST_LABEL_VERSION = __('Version');
export const LIST_LABEL_PACKAGE_TYPE = __('Type');
export const LIST_LABEL_CREATED_AT = __('Published');

export const SORT_FIELDS = [
  {
    orderBy: LIST_KEY_NAME,
    label: LIST_LABEL_NAME,
  },
  {
    orderBy: LIST_KEY_PROJECT,
    label: LIST_LABEL_PROJECT,
  },
  {
    orderBy: LIST_KEY_VERSION,
    label: LIST_LABEL_VERSION,
  },
  {
    orderBy: LIST_KEY_PACKAGE_TYPE,
    label: LIST_LABEL_PACKAGE_TYPE,
  },
  {
    orderBy: LIST_KEY_CREATED_AT,
    label: LIST_LABEL_CREATED_AT,
  },
];

export const PACKAGE_TYPES = [
  s__('PackageRegistry|Composer'),
  s__('PackageRegistry|Conan'),
  s__('PackageRegistry|Generic'),
  s__('PackageRegistry|Maven'),
  s__('PackageRegistry|npm'),
  s__('PackageRegistry|NuGet'),
  s__('PackageRegistry|PyPI'),
  s__('PackageRegistry|RubyGems'),
  s__('PackageRegistry|Debian'),
  s__('PackageRegistry|Helm'),
];

// links

export const EMPTY_LIST_HELP_URL = helpPagePath('user/packages/package_registry/index');
export const PACKAGE_HELP_URL = helpPagePath('user/packages/index');
export const NPM_HELP_PATH = helpPagePath('user/packages/npm_registry/index');
export const MAVEN_HELP_PATH = helpPagePath('user/packages/maven_repository/index');
export const CONAN_HELP_PATH = helpPagePath('user/packages/conan_repository/index');
export const NUGET_HELP_PATH = helpPagePath('user/packages/nuget_repository/index');
export const PYPI_HELP_PATH = helpPagePath('user/packages/pypi_repository/index');
export const COMPOSER_HELP_PATH = helpPagePath('user/packages/composer_repository/index');

export const GRAPHQL_PACKAGE_PIPELINES_PAGE_SIZE = 10;
