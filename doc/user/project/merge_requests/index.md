---
stage: Create
group: Code Review
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
type: index, reference
---

# Merge requests **(FREE)**

Merge requests (MRs) are the way you check source code changes into a branch.
When you open a merge request, you can visualize and collaborate on the code changes before merge.
Merge requests include:

- A description of the request.
- Code changes and inline code reviews.
- Information about CI/CD pipelines.
- A comment section for discussion threads.
- The list of commits.

Read more about [how to get started](getting_started.md).

## View merge requests

You can view merge requests for your project, group, or yourself.

### View merge requests for a project

To view all merge requests for a project:

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Merge requests**.

Or, to use a [keyboard shortcut](../../shortcuts.md), press <kbd>g</kbd> + <kbd>m</kbd>.

### View merge requests for all projects in a group

To view merge requests for all projects in a group:

1. On the top bar, select **Menu > Groups** and find your group.
1. On the left sidebar, select **Merge requests**.

If your group contains subgroups, this view also displays merge requests from the subgroup projects.

## View all merge requests assigned to you

To view all merge requests assigned to you:

<!-- vale gitlab.FirstPerson = NO -->

1. On the top bar, put your cursor in the **Search** box.
1. From the dropdown list, select **Merge requests assigned to me**.

<!-- vale gitlab.FirstPerson = YES -->

Or:

- To use a [keyboard shortcut](../../shortcuts.md), press <kbd>Shift</kbd> + <kbd>m</kbd>.
- On the top bar, on the top right, select **{merge-request-open}** **Merge requests**.
  Then select one of the following:
  - [Review requests](reviews/index.md).
  - Merge requests assigned.

## Filter the list of merge requests

To filter the list of merge requests:

1. Above the list of merge requests, select **Search or filter results...**.
1. In the dropdown list that appears, select the attribute you wish to filter by.
1. Select or type the operator to use for filtering the attribute. The following operators are
   available:
   - `=`: Is
   - `!=`: Is not ([Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/18059) in GitLab 12.7)
1. Enter the text to filter the attribute by.
   You can filter some attributes by **None** or **Any**.
1. Repeat this process to filter by multiple attributes. Multiple attributes are joined by a logical
   `AND`.

GitLab displays the results on-screen, but you can also
[retrieve them as an RSS feed](../../search/index.md#retrieve-search-results-as-feed).

### Filter merge requests by ID

> [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/-/issues/39908) in GitLab 12.1.

You can filter the **Merge Request** list to find merge requests by their ID.

For example, enter filter `#30` to return only merge request 30.

### Filter merge requests by approvers **(PREMIUM)**

> Moved to GitLab Premium in 13.9.

To filter merge requests by an individual eligible approver ([Code owner](../code_owners.md)), you can type (or select from
the dropdown list) **Approver** and select the user.

![Filter MRs by an approver](img/filter_approver_merge_requests_v14_6.png)

### Filter merge requests by "approved by" **(PREMIUM)**

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/30335) in GitLab 13.0.
> - Moved to GitLab Premium in 13.9.

To filter merge requests already approved by a specific individual, you can type (or select from
the dropdown list) **Approved-By** and select the user.

![Filter MRs by approved by](img/filter_approved_by_merge_requests_v14_6.png)

### Filter merge requests by reviewer

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/47605) in GitLab 13.7.

To filter review requested merge requests for a specific individual, you can type (or select from
the dropdown list) **Reviewer** and select the user.

### Filter merge requests by environment or deployment date

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/44041) in GitLab 13.6.

To filter merge requests by deployment data, such as the environment or a date,
you can type (or select from the dropdown list) the following:

- Environment
- Deployed-before
- Deployed-after

NOTE:
Projects using a [fast-forward merge method](methods/index.md#fast-forward-merge)
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

## Add changes to a merge request

If you have permission to add changes to a merge request, you can add your changes
to an existing merge request in several ways, depending on the complexity of your
change and whether you need access to a development environment:

- [Edit changes in the Web IDE](../web_ide/index.md) in your browser with the
  <kbd>.</kbd> [keyboard shortcut](../../shortcuts.md). Use this
  browser-based method to edit multiple files, or if you are not comfortable with Git commands.
  You cannot run tests from the Web IDE.
- [Edit changes in Gitpod](../../../integration/gitpod.md#launch-gitpod-in-gitlab), if you
  need a fully-featured environment to both edit files, and run tests afterward. Gitpod
  supports running the [GitLab Development Kit (GDK)](https://gitlab.com/gitlab-org/gitlab-development-kit).
  To use Gitpod, you must [enable Gitpod in your user account](../../../integration/gitpod.md#enable-gitpod-in-your-user-settings).
- [Push changes from the command line](../../../gitlab-basics/start-using-git.md), if you are
  familiar with Git and the command line.

## Assign a user to a merge request

When a merge request is created, it's assigned by default to the person who created it.
This person owns the merge request, but isn't responsible for [reviewing it](reviews/index.md).
To assign the merge request to someone else, use the `/assign @user`
[quick action](../quick_actions.md#issues-merge-requests-and-epics) in a text area in
a merge request, or:

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Merge requests** and find your merge request.
1. On the right sidebar, expand the right sidebar and locate the **Assignees** section.
1. Select **Edit**.
1. Search for the user you want to assign, and select the user.

The merge request is added to the user's assigned merge request list.

### Assign multiple users **(PREMIUM)**

> Moved to GitLab Premium in 13.9.

GitLab enables multiple assignees for merge requests, if multiple people are
accountable for it:

![multiple assignees for merge requests sidebar](img/multiple_assignees_for_merge_requests_sidebar.png)

To assign multiple assignees to a merge request, use the `/assign @user`
[quick action](../quick_actions.md#issues-merge-requests-and-epics) in a text area, or:

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Merge requests** and find your merge request.
1. On the right sidebar, expand the right sidebar and locate the **Assignees** section.
1. Select **Edit** and, from the dropdown list, select all users you want
   to assign the merge request to.

To remove an assignee, clear the user from the same dropdown list.

## Close a merge request

If you decide to permanently stop work on a merge request,
GitLab recommends you close the merge request rather than
[delete it](#delete-a-merge-request). The author and assignees of a merge request, and users with
Developer, Maintainer, or Owner [roles](../../permissions.md) in a project
can close merge requests in the project:

1. Go to the merge request you want to close.
1. Scroll to the comment box at the bottom of the page.
1. Following the comment box, select **Close merge request**.

GitLab closes the merge request, but preserves records of the merge request,
its comments, and any associated pipelines.

### Delete a merge request

GitLab recommends you close, rather than delete, merge requests.

WARNING:
You cannot undo the deletion of a merge request.

To delete a merge request:

1. Sign in to GitLab as a user with the project Owner role.
   Only users with this role can delete merge requests in a project.
1. Go to the merge request you want to delete, and select **Edit**.
1. Scroll to the bottom of the page, and select **Delete merge request**.

### Update merge requests when target branch merges **(FREE SELF)**

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/320902) in GitLab 13.9.
> - [Disabled on self-managed](https://gitlab.com/gitlab-org/gitlab/-/issues/320902) in GitLab 13.9.
> - [Enabled on self-managed](https://gitlab.com/gitlab-org/gitlab/-/issues/320895) GitLab 13.10.

Merge requests are often chained together, with one merge request depending on
the code added or changed in another merge request. To support keeping individual
merge requests small, GitLab can update up to four open merge requests when their
target branch merges into `main`. For example:

- **Merge request 1**: merge `feature-alpha` into `main`.
- **Merge request 2**: merge `feature-beta` into `feature-alpha`.

If these merge requests are open at the same time, and merge request 1 (`feature-alpha`)
merges into `main`, GitLab updates the destination of merge request 2 from `feature-alpha`
to `main`.

Merge requests with interconnected content updates are usually handled in one of these ways:

- Merge request 1 is merged into `main` first. Merge request 2 is then
  retargeted to `main`.
- Merge request 2 is merged into `feature-alpha`. The updated merge request 1, which
  now contains the contents of `feature-alpha` and `feature-beta`, is merged into `main`.

This feature works only when a merge request is merged. Selecting **Remove source branch**
after merging does not retarget open merge requests. This improvement is
[proposed as a follow-up](https://gitlab.com/gitlab-org/gitlab/-/issues/321559).

## Merge request workflows

For a software developer working in a team:

1. You checkout a new branch, and submit your changes through a merge request.
1. You gather feedback from your team.
1. You work on the implementation optimizing code with [Code Quality reports](../../../ci/testing/code_quality.md).
1. You verify your changes with [Unit test reports](../../../ci/testing/unit_test_reports.md) in GitLab CI/CD.
1. You avoid using dependencies whose license is not compatible with your project with [License Compliance reports](../../compliance/license_compliance/index.md).
1. You request the [approval](approvals/index.md) from your manager.
1. Your manager:
   1. Pushes a commit with their final review.
   1. [Approves the merge request](approvals/index.md).
   1. Sets it to [merge when pipeline succeeds](merge_when_pipeline_succeeds.md).
1. Your changes get deployed to production with [manual jobs](../../../ci/jobs/job_control.md#create-a-job-that-must-be-run-manually) for GitLab CI/CD.
1. Your implementations were successfully shipped to your customer.

For a web developer writing a webpage for your company's website:

1. You checkout a new branch and submit a new page through a merge request.
1. You gather feedback from your reviewers.
1. You preview your changes with [Review Apps](../../../ci/review_apps/index.md).
1. You request your web designers for their implementation.
1. You request the [approval](approvals/index.md) from your manager.
1. Once approved, your merge request is [squashed and merged](squash_and_merge.md), and [deployed to staging with GitLab Pages](https://about.gitlab.com/blog/2021/02/05/ci-deployment-and-environments/).
1. Your production team [cherry-picks](cherry_pick_changes.md) the merge commit into production.

## Related topics

- [Create a merge request](creating_merge_requests.md)
- [Review a merge request](reviews/index.md)
- [Authorization for merge requests](authorization_for_merge_requests.md)
- [Testing and reports](../../../ci/testing/index.md)
- [GitLab keyboard shortcuts](../../shortcuts.md)
- [Comments and threads](../../discussions/index.md)
- [Suggest code changes](reviews/suggestions.md)
- [Commits](commits.md)
- [CI/CD pipelines](../../../ci/index.md)
- [Push options](../push_options.md) for merge requests
