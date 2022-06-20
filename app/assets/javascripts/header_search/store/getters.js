import { omitBy, isNil } from 'lodash';
import { objectToQuery } from '~/lib/utils/url_utility';

import {
  MSG_ISSUES_ASSIGNED_TO_ME,
  MSG_ISSUES_IVE_CREATED,
  MSG_MR_ASSIGNED_TO_ME,
  MSG_MR_IM_REVIEWER,
  MSG_MR_IVE_CREATED,
  MSG_IN_PROJECT,
  MSG_IN_GROUP,
  MSG_IN_ALL_GITLAB,
} from '../constants';

export const searchQuery = (state) => {
  const query = omitBy(
    {
      search: state.search,
      nav_source: 'navbar',
      project_id: state.searchContext?.project?.id,
      group_id: state.searchContext?.group?.id,
      scope: state.searchContext?.scope,
      snippets: state.searchContext?.for_snippets ? true : null,
      search_code: state.searchContext?.code_search ? true : null,
      repository_ref: state.searchContext?.ref,
    },
    isNil,
  );

  return `${state.searchPath}?${objectToQuery(query)}`;
};

export const autocompleteQuery = (state) => {
  const query = omitBy(
    {
      term: state.search,
      project_id: state.searchContext?.project?.id,
      project_ref: state.searchContext?.ref,
    },
    isNil,
  );

  return `${state.autocompletePath}?${objectToQuery(query)}`;
};

export const scopedIssuesPath = (state) => {
  return (
    state.searchContext?.project_metadata?.issues_path ||
    state.searchContext?.group_metadata?.issues_path ||
    state.issuesPath
  );
};

export const scopedMRPath = (state) => {
  return (
    state.searchContext?.project_metadata?.mr_path ||
    state.searchContext?.group_metadata?.mr_path ||
    state.mrPath
  );
};

export const defaultSearchOptions = (state, getters) => {
  const userName = gon.current_username;

  return [
    {
      html_id: 'default-issues-assigned',
      title: MSG_ISSUES_ASSIGNED_TO_ME,
      url: `${getters.scopedIssuesPath}/?assignee_username=${userName}`,
    },
    {
      html_id: 'default-issues-created',
      title: MSG_ISSUES_IVE_CREATED,
      url: `${getters.scopedIssuesPath}/?author_username=${userName}`,
    },
    {
      html_id: 'default-mrs-assigned',
      title: MSG_MR_ASSIGNED_TO_ME,
      url: `${getters.scopedMRPath}/?assignee_username=${userName}`,
    },
    {
      html_id: 'default-mrs-reviewer',
      title: MSG_MR_IM_REVIEWER,
      url: `${getters.scopedMRPath}/?reviewer_username=${userName}`,
    },
    {
      html_id: 'default-mrs-created',
      title: MSG_MR_IVE_CREATED,
      url: `${getters.scopedMRPath}/?author_username=${userName}`,
    },
  ];
};

export const projectUrl = (state) => {
  const query = omitBy(
    {
      search: state.search,
      nav_source: 'navbar',
      project_id: state.searchContext?.project?.id,
      group_id: state.searchContext?.group?.id,
      scope: state.searchContext?.scope,
      snippets: state.searchContext?.for_snippets ? true : null,
      search_code: state.searchContext?.code_search ? true : null,
      repository_ref: state.searchContext?.ref,
    },
    isNil,
  );

  return `${state.searchPath}?${objectToQuery(query)}`;
};

export const groupUrl = (state) => {
  const query = omitBy(
    {
      search: state.search,
      nav_source: 'navbar',
      group_id: state.searchContext?.group?.id,
      scope: state.searchContext?.scope,
      snippets: state.searchContext?.for_snippets ? true : null,
      search_code: state.searchContext?.code_search ? true : null,
      repository_ref: state.searchContext?.ref,
    },
    isNil,
  );

  return `${state.searchPath}?${objectToQuery(query)}`;
};

export const allUrl = (state) => {
  const query = omitBy(
    {
      search: state.search,
      nav_source: 'navbar',
      scope: state.searchContext?.scope,
      snippets: state.searchContext?.for_snippets ? true : null,
      search_code: state.searchContext?.code_search ? true : null,
      repository_ref: state.searchContext?.ref,
    },
    isNil,
  );

  return `${state.searchPath}?${objectToQuery(query)}`;
};

export const scopedSearchOptions = (state, getters) => {
  const options = [];

  if (state.searchContext?.project) {
    options.push({
      html_id: 'scoped-in-project',
      scope: state.searchContext.project?.name || '',
      description: MSG_IN_PROJECT,
      url: getters.projectUrl,
    });
  }

  if (state.searchContext?.group) {
    options.push({
      html_id: 'scoped-in-group',
      scope: state.searchContext.group?.name || '',
      description: MSG_IN_GROUP,
      url: getters.groupUrl,
    });
  }

  options.push({
    html_id: 'scoped-in-all',
    description: MSG_IN_ALL_GITLAB,
    url: getters.allUrl,
  });

  return options;
};

export const autocompleteGroupedSearchOptions = (state) => {
  const groupedOptions = {};
  const results = [];

  state.autocompleteOptions.forEach((option) => {
    const category = groupedOptions[option.category];

    if (category) {
      category.data.push(option);
    } else {
      groupedOptions[option.category] = {
        category: option.category,
        data: [option],
      };

      results.push(groupedOptions[option.category]);
    }
  });
  return results;
};

export const searchOptions = (state, getters) => {
  if (!state.search) {
    return getters.defaultSearchOptions;
  }

  const sortedAutocompleteOptions = Object.values(getters.autocompleteGroupedSearchOptions).reduce(
    (options, group) => {
      return [...options, ...group.data];
    },
    [],
  );

  return getters.scopedSearchOptions.concat(sortedAutocompleteOptions);
};
