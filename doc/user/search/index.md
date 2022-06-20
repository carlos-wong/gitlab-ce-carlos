---
stage: Create
group: Editor
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Searching in GitLab **(FREE)**

## Search issues and merge requests

To search through issues and merge requests in multiple projects, on the top bar, select the **Issues** or **Merge requests** links.

The numbers indicate how many issues, merge requests, and to-do items are assigned to you:

![issues and MRs dashboard links](img/dashboard_links_v14_6.png)

- **{issues}** **Issues**: Issues assigned to you.
- **{merge-request-open}** **Merge requests**: Open [merge requests](../project/merge_requests/index.md).
  Select the icon to show a dropdown list of merge request filters:
  - [Attention requests](../project/merge_requests/index.md#request-attention-to-a-merge-request) (**{attention-solid}**) for you.
  - [Review requests](../project/merge_requests/reviews/index.md) for you.
  - Merge requests assigned to you.
- **{todo-done}** **To-do items**: The [to-do items](../todos.md) assigned to you.

You can search through **Open**, **Closed**, or **All** issues.

You can also filter the results using the search and filter field, as described in
[Filter issue and merge request lists](#filter-issue-and-merge-request-lists).

### Issues and MRs assigned to you or created by you

GitLab shows shortcuts to issues and merge requests created by you or assigned to you
in the search field in the upper right corner:

![shortcut to your issues and merge requests](img/issues_mrs_shortcut_v14_6.png)

### Filter issue and merge request lists

> - Filtering by epics was [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/195704) in GitLab 12.9.
> - Filtering by child epics was [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/9029) in GitLab 13.0.
> - Filtering by iterations was [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/118742) in GitLab 13.6.
> - Filtering by iterations was moved from GitLab Ultimate to GitLab Premium in 13.9.
> - Filtering by type was [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/322755) in GitLab 13.10 [with a flag](../../administration/feature_flags.md) named `vue_issues_list`. Disabled by default.
> - Filtering by type was [enabled on self-managed](https://gitlab.com/gitlab-org/gitlab/-/issues/322755) in GitLab 14.10.
> - Filtering by attention request was [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/343528) in GitLab 14.10 [with a flag](../../administration/feature_flags.md) named `mr_attention_requests`. Disabled by default.

Follow these steps to filter the **Issues** and **Merge requests** list pages in projects and
groups:

1. Select **Search or filter results...**.
1. In the dropdown list that appears, select the attribute you wish to filter by:
   - Assignee
   - [Attention requests](../project/merge_requests/index.md#request-attention-to-a-merge-request)
   - Author
   - Confidential
   - [Epic and child Epic](../group/epics/index.md) (available only for the group the Epic was created, not for [higher group levels](https://gitlab.com/gitlab-org/gitlab/-/issues/233729)).
   - [Iteration](../group/iterations/index.md)
   - [Label](../project/labels.md)
   - [Milestone](../project/milestones/index.md)
   - My-reaction
   - Release
   - Type
   - Weight
   - Search for this text
1. Select or type the operator to use for filtering the attribute. The following operators are
   available:
   - `=`: Is
   - `!=`: Is not ([Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/18059) in GitLab 12.7)
1. Enter the text to [filter the attribute by](#filters-autocomplete).
   You can filter some attributes by **None** or **Any**.
1. Repeat this process to filter by multiple attributes. Multiple attributes are joined by a logical
   `AND`.

GitLab displays the results on-screen, but you can also
[retrieve them as an RSS feed](#retrieve-search-results-as-feed).

### Searching for specific terms

You can filter issues and merge requests by specific terms included in titles or descriptions.

- Syntax
  - Searches look for all the words in a query, in any order. For example: searching
    issues for `display bug` returns all issues matching both those words, in any order.
  - To find the exact term, use double quotes: `"display bug"`
- Limitation
  - For performance reasons, terms shorter than 3 chars are ignored. For example: searching
    issues for `included in titles` is same as `included titles`
  - Search is limited to 4096 characters and 64 terms per query.

### Retrieve search results as feed

> Feeds for merge requests were [introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/66336) in GitLab 14.3.

GitLab provides RSS feeds of search results for your project. To subscribe to the
RSS feed of search results:

1. Go to your project's page.
1. On the left sidebar, select **Issues** or **Merge requests**.
1. Build your search query as described in [Filter issue and merge request lists](#filter-issue-and-merge-request-lists).
1. Select the feed symbol **{rss}** to display the results as an RSS feed in Atom format.

The URL of the result contains both a feed token, and your search query.
You can add this URL to your feed reader.

### Filtering by ID

> [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/-/issues/39908) in GitLab 12.1.

You can filter the **Issues** list to individual instances by their ID. For example, enter filter `#10` to return only issue 10. The same applies to the **Merge requests** list. Enter filter `#30` to return only merge request 30.

![filter issues by specific ID](img/issue_search_by_id.png)

### Filtering merge requests by approvers **(PREMIUM)**

> Moved to GitLab Premium in 13.9.

To filter merge requests by an individual eligible approver ([Codeowner](../project/code_owners.md)), you can type (or select from
the dropdown list) **Approver** and select the user.

![Filter MRs by an approver](img/filter_approver_merge_requests_v14_6.png)

### Filtering merge requests by "approved by" **(PREMIUM)**

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/30335) in GitLab 13.0.
> - Moved to GitLab Premium in 13.9.

To filter merge requests already approved by a specific individual, you can type (or select from
the dropdown list) **Approved-By** and select the user.

![Filter MRs by approved by](img/filter_approved_by_merge_requests_v14_6.png)

### Filtering merge requests by reviewer

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/47605) in GitLab 13.7.

To filter review requested merge requests for a specific individual, you can type (or select from
the dropdown list) **Reviewer** and select the user.

### Filtering merge requests by environment or deployment date

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/44041) in GitLab 13.6.

To filter merge requests by deployment data, such as the environment or a date,
you can type (or select from the dropdown list) the following:

- Environment
- Deployed-before
- Deployed-after

NOTE:
Projects using a [fast-forward merge method](../project/merge_requests/fast_forward_merge.md)
do not return results, as this method does not create a merge commit.

When filtering by an environment, a dropdown list presents all environments that
you can choose from:

![Filter MRs by their environment](img/filtering_merge_requests_by_environment_v14_6.png)

When filtering by `Deployed-before` or `Deployed-after`, the date refers to when
the deployment to an environment (triggered by the merge commit) completed successfully.
You must enter the deploy date manually. Deploy dates
use the format `YYYY-MM-DD`, and must be quoted if you wish to specify
both a date and time (`"YYYY-MM-DD HH:MM"`):

![Filter MRs by a deploy date](img/filtering_merge_requests_by_date_v14_6.png)

## Filters autocomplete

GitLab provides many filters across many pages (issues, merge requests, epics,
and pipelines among others) which you can use to narrow down your search. When
using the filter functionality, you can start typing characters to bring up
relevant users or other attributes.

For performance optimization, there is a requirement of a minimum of three
characters to begin your search. To search for issues with the assignee `Simone Presley`,
you must type at least `Sim` before autocomplete displays results.

## Search history

Search history is available for issues and merge requests, and is stored locally
in your browser. To run a search from history:

1. In the top menu, select **Issues** or **Merge requests**.
1. To the left of the search bar, click **Recent searches**, and select a search from the list.

## Removing search filters

Individual filters can be removed by clicking on the filter's (x) button or backspacing. The entire search filter can be cleared by clicking on the search box's (x) button or via <kbd>⌘</kbd> (Mac) + <kbd>⌫</kbd>.

To delete filter tokens one at a time, the <kbd>⌥</kbd> (Mac) / <kbd>Control</kbd> + <kbd>⌫</kbd> keyboard combination can be used.

## Filtering with multiple filters of the same type

Some filters can be added multiple times. These include but are not limited to assignees and labels. When you filter with these multiple filters of the same type, the `AND` logic is applied. For example, if you were filtering `assignee:@sam assignee:@sarah`, your results include only entries whereby the assignees are assigned to both Sam and Sarah are returned.

![multiple assignees filtering](img/multiple_assignees.png)

## To-Do List

You can search your [To-Do List](../todos.md) by "to do" and "done".
You can filter to-do items per project, author, type, and action.
Also, you can sort them by [**Label priority**](../../user/project/labels.md#set-label-priority),
**Last created**, and **Oldest created**.

## Projects

You can search through your projects from the top bar, by selecting **Menu > Projects**.
On the field **Filter by name**, type the project or group name you want to find, and GitLab
filters them for you as you type.

You can also look for the projects you [starred](../project/working_with_projects.md#star-a-project) (**Starred projects**).
You can **Explore** all public and internal projects available in GitLab.com, from which you can filter by visibility,
through **Trending**, best rated with **Most stars**, or **All** of them.

You can also sort them by:

- Name
- Created date
- Updated date
- Owner

You can also choose to hide or show archived projects.

## Groups

Similarly to [projects search](#projects), you can search through your groups from
the left menu, by clicking the menu bar, then **Groups**.

On the field **Filter by name**, type the group name you want to find, and GitLab
filters them for you as you type.

You can also **Explore** all public and internal groups available in GitLab.com,
and sort them by **Name**, **Last created**, **Oldest created**, or **Updated date**.

## Issue boards

From an [issue board](../../user/project/issue_board.md), you can filter issues by **Author**, **Assignee**, **Milestone**, and **Labels**.
You can also filter them by name (issue title), from the field **Filter by name**, which is loaded as you type.

To search for issues to add to lists present in your issue board, select
the button **Add issues** on the top-right of your screen, opening a modal window from which
you can, besides filtering them by **Name**, **Author**, **Assignee**, **Milestone**,
and **Labels**, select multiple issues to add to a list of your choice:

![search and select issues to add to board](img/search_issues_board.png)

## Autocomplete suggestions

In the search bar, you can view autocomplete suggestions for:

- Projects and groups
- Various help pages (try and type **API help**)
- Project feature pages (try and type **milestones**)
- Various settings pages (try and type **user settings**)
- Recently viewed issues (try and type some word from the title of a recently viewed issue)
- Recently viewed merge requests (try and type some word from the title of a recently viewed merge request)
- Recently viewed epics (try and type some word from the title of a recently viewed epic)
- [GitLab Flavored Markdown](../markdown.md#gitlab-specific-references) (GLFM) for issues in a project (try and type a GLFM reference for an issue)

## Basic search

The Basic search in GitLab enables you to search
across the entire GitLab instance, in a group, or in a single project. Basic search is
backed by the database and allows searching in:

- Projects
- Issues
- Merge requests
- Milestones
- Users
- Epics (Group only)
- Code (Project only)
- Comments (Project only)
- Commits (Project only)
- Wiki (Project only)

To start a search, type into the search bar on the top-right of the screen. You can always search
in all GitLab and may also see the options to search in a group or project if you are in the
group or project dashboard.

![basic search](img/basic_search_v14_4.png)

After the results are returned, you can modify the search, select a different type of data to
search, or choose a specific group or project.

![basic_search_results](img/basic_search_results.png)

### Code search

To search through code or other documents in a single project, you can use
the search field on the top-right of your screen while the project page is open.
Code search shows only the first result in the file.

#### Git blame from code search **(FREE)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/327052) in GitLab 14.7.

You can access Git blame from any line that returned a result from the code search:

![code search results](img/code_search_git_blame_v14_9.png)

### SHA search

You can quickly access a commit from the project dashboard by entering the SHA
into the search field on the top right of the screen. If a single result is found, you are
redirected to the commit result and given the option to return to the search results page.

![project SHA search redirect](img/project_search_sha_redirect.png)

## Advanced Search **(PREMIUM)**

Leverage Elasticsearch for faster, more advanced code search across your entire
GitLab instance.

[Learn how to use the Advanced Search.](advanced_search.md)

## Search settings

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/292941) in GitLab 13.8 [with a flag](../../administration/feature_flags.md) named `search_settings_in_page`. Disabled by default.
> - [Added](https://gitlab.com/groups/gitlab-org/-/epics/4842) to Group, Administrator, and User settings in GitLab 13.9.
> - [Feature flag `search_settings_in_page` removed](https://gitlab.com/gitlab-org/gitlab/-/issues/294025) in GitLab 13.11.
> - [Generally available](https://gitlab.com/gitlab-org/gitlab/-/issues/294025) in GitLab 13.11.

You can search inside a Project, Group, Administrator, or User's settings by entering
a search term in the search box located at the top of the page. The search results
appear highlighted in the sections that match the search term.

![Search project settings](img/project_search_general_settings_v13_8.png)
