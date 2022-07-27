---
stage: Plan
group: Project Management
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Manage issues **(FREE)**

[GitLab Issues](index.md) are the fundamental medium for collaborating on ideas and
planning work in GitLab.

## Create an issue

When you create an issue, you are prompted to enter the fields of the issue.
If you know the values you want to assign to an issue, you can use
[quick actions](../quick_actions.md) to enter them.

You can create an issue in many ways in GitLab:

- [From a project](#from-a-project)
- [From a group](#from-a-group)
- [From another issue or incident](#from-another-issue-or-incident)
- [From an issue board](#from-an-issue-board)
- [By sending an email](#by-sending-an-email)
- [Using a URL with prefilled values](#using-a-url-with-prefilled-values)
- [Using Service Desk](#using-service-desk)

### From a project

Prerequisites:

- You must have at least the Guest role for the project.

To create an issue:

1. On the top bar, select **Menu > Projects** and find your project.
1. Either:

   - On the left sidebar, select **Issues**, and then, in the top right corner, select **New issue**.
   - On the top bar, select the plus sign (**{plus-square}**) and then, under **This project**,
     select **New issue**.

1. Complete the [fields](#fields-in-the-new-issue-form).
1. Select **Create issue**.

The newly created issue opens.

### From a group

Issues belong to projects, but when you're in a group, you can access and create issues that belong
to the projects in the group.

Prerequisites:

- You must have at least the Guest role for the project in the group.

To create an issue from a group:

1. On the top bar, select **Menu > Groups** and find your group.
1. On the left sidebar, select **Issues**.
1. In the top right corner, select **Select project to create issue**.
1. Select the project you'd like to create an issue for. The button now reflects the selected
   project.
1. Select **New issue in `<project name>`**.
1. Complete the [fields](#fields-in-the-new-issue-form).
1. Select **Create issue**.

The newly created issue opens.

The project you selected most recently becomes the default for your next visit.
This can save you a lot of time and clicks, if you mostly create issues for the same project.

### From another issue or incident

> - New issue becoming linked to the issue of origin [introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/68226) in GitLab 14.3.
> - **Relate to…** checkbox [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/198494) in GitLab 14.9.

You can create a new issue from an existing one. The two issues can then be marked as related.

Prerequisites:

- You must have at least the Guest role for the project.

To create an issue from another issue:

1. In an existing issue, select the vertical ellipsis (**{ellipsis_v}**).
1. Select **New related issue**.
1. Complete the [fields](#fields-in-the-new-issue-form).
   The new issue form has a **Relate to issue #123** checkbox, where `123` is the ID of the
   issue of origin. If you keep this checkbox checked, the two issues become
   [linked](related_issues.md).
1. Select **Create issue**.

The newly created issue opens.

### From an issue board

You can create a new issue from an [issue board](../issue_board.md).

Prerequisites:

- You must have at least the Guest role for the project.

To create an issue from a project issue board:

1. On the top bar, select **Menu > Projects** and find your project.
1. Select **Issues > Boards**.
1. At the top of a board list, select **New issue** (**{plus-square}**).
1. Enter the issue's title.
1. Select **Create issue**.

To create an issue from a group issue board:

1. On the top bar, select **Menu > Groups** and find your group.
1. Select **Issues > Boards**.
1. At the top of a board list, select **New issue** (**{plus-square}**).
1. Enter the issue's title.
1. Under **Projects**, select the project in the group that the issue should belong to.
1. Select **Create issue**.

The issue is created and shows up in the board list. It shares the list's characteristic, so, for
example, if the list is scoped to a label `Frontend`, the new issue also has this label.

### By sending an email

> Generated email address format changed in GitLab 11.7.
> The older format is still supported, so existing aliases and contacts still work.

You can send an email to create an issue in a project on the project's
**Issues List** page.

Prerequisites:

- Your GitLab instance must have [incoming email](../../../administration/incoming_email.md)
  configured.
- There must be at least one issue in the issue list.
- You must have at least the Guest role for the project.

To email an issue to a project:

1. On the top bar, select **Menu > Projects** and find your project.
1. Select **Issues**.
1. At the bottom of the page, select **Email a new issue to this project**.
1. To copy the email address, select **Copy** (**{copy-to-clipboard}**).
1. From your email client, send an email to this address.
   The subject is used as the title of the new issue, and the email body becomes the description.
   You can use [Markdown](../../markdown.md) and [quick actions](../quick_actions.md).

A new issue is created, with your user as the author.
You can save this address as a contact in your email client to use it again.

WARNING:
The email address you see is a private email address, generated just for you.
**Keep it to yourself**, because anyone who knows it can create issues or merge requests as if they
were you.

To regenerate the email address:

1. On the issues list, select **Email a new issue to this project**.
1. Select **reset this token**.

### Using a URL with prefilled values

> - Ability to use both `issuable_template` and `issue[description]` in the same URL [introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/80554) in GitLab 14.9.
> - Ability to specify `add_related_issue` [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/198494) in GitLab 14.9.

To link directly to the new issue page with prefilled fields, use query
string parameters in a URL. You can embed a URL in an external
HTML page to create issues with certain fields prefilled.

| Field                | URL parameter         | Notes                                                                                                                           |
| -------------------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Title                | `issue[title]`        | Must be [URL-encoded](../../../api/index.md#namespaced-path-encoding).                                                          |
| Issue type           | `issue[issue_type]`   | Either `incident` or `issue`.                                                                                                   |
| Description template | `issuable_template`   | Must be [URL-encoded](../../../api/index.md#namespaced-path-encoding).                                                          |
| Description          | `issue[description]`  | Must be [URL-encoded](../../../api/index.md#namespaced-path-encoding). If used in combination with `issuable_template` or a [default issue template](../description_templates.md#set-a-default-template-for-merge-requests-and-issues), the `issue[description]` value is appended to the template. |
| Confidential         | `issue[confidential]` | If `true`, the issue is marked as confidential.                                                                                 |
| Relate to…           | `add_related_issue`   | A numeric issue ID. If present, the issue form shows a [**Relate to…** checkbox](#from-another-issue-or-incident) to optionally link the new issue to the specified existing issue. |

Adapt these examples to form your new issue URL with prefilled fields.
To create an issue in the GitLab project:

- With a prefilled title and description:

  ```plaintext
  https://gitlab.com/gitlab-org/gitlab/-/issues/new?issue[title]=Whoa%2C%20we%27re%20half-way%20there&issue[description]=Whoa%2C%20livin%27%20in%20a%20URL
  ```

- With a prefilled title and description template:

  ```plaintext
  https://gitlab.com/gitlab-org/gitlab/-/issues/new?issue[title]=Validate%20new%20concept&issuable_template=Feature%20Proposal%20-%20basic
  ```

- With a prefilled title, description, and marked as confidential:

  ```plaintext
  https://gitlab.com/gitlab-org/gitlab/-/issues/new?issue[title]=Validate%20new%20concept&issue[description]=Research%20idea&issue[confidential]=true
  ```

### Using Service Desk

To offer email support, enable [Service Desk](../service_desk.md) for your project.

Now, when your customer sends a new email, a new issue can be created in
the appropriate project and followed up from there.

### Fields in the new issue form

> Adding the new issue to an epic [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/13847) in GitLab 13.1.

When you're creating a new issue, you can complete the following fields:

- Title
- Type: either issue (default) or incident
- [Description template](../description_templates.md): overwrites anything in the Description text box
- Description: you can use [Markdown](../../markdown.md) and [quick actions](../quick_actions.md)
- Checkbox to make the issue [confidential](confidential_issues.md)
- [Assignees](#assignee)
- [Weight](issue_weight.md)
- [Epic](../../group/epics/index.md)
- [Due date](due_dates.md)
- [Milestone](../milestones/index.md)
- [Labels](../labels.md)

## Edit an issue

You can edit an issue's title and description.

Prerequisites:

- You must have at least the Reporter role for the project, be the author of the issue, or be assigned to the issue.

To edit an issue:

1. To the right of the title, select **Edit title and description** (**{pencil}**).
1. Edit the available fields.
1. Select **Save changes**.

### Reorder list items in the issue description

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/15260) in GitLab 15.0.

When you view an issue that has a list in the description, you can also reorder the list items.

Prerequisites:

- You must have at least the Reporter role for the project, be the author of the issue, or be
  assigned to the issue.
- The issue's description must have an [ordered, unordered](../../markdown.md#lists), or
  [task](../../markdown.md#task-lists) list.

To reorder list items, when viewing an issue:

1. Hover over the list item row to make the drag icon (**{drag-vertical}**) visible.
1. Select and hold the drag icon.
1. Drag the row to the new position in the list.
1. Release the drag icon.

### Bulk edit issues from a project

> - Assigning epic [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/210470) in GitLab 13.2.
> - Editing health status [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/218395) in GitLab 13.2.
> - Editing iteration [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/196806) in GitLab 13.9.

You can edit multiple issues at a time when you're in a project.

Prerequisites:

- You must have at least the Reporter role for the project.

To edit multiple issues at the same time:

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Issues**.
1. Select **Edit issues**. A sidebar on the right of your screen appears.
1. Select the checkboxes next to each issue you want to edit.
1. From the sidebar, edit the available fields.
1. Select **Update all**.

When bulk editing issues in a project, you can edit the following attributes:

- Status (open or closed)
- [Assignees](#assignee)
- [Epic](../../group/epics/index.md)
- [Milestone](../milestones/index.md)
- [Labels](../labels.md)
- [Health status](#health-status)
- [Notification](../../profile/notifications.md) subscription
- [Iteration](../../group/iterations/index.md)

### Bulk edit issues from a group **(PREMIUM)**

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/7249) in GitLab 12.1.
> - Assigning epic [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/210470) in GitLab 13.2.
> - Editing health status [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/218395) in GitLab 13.2.
> - Editing iteration [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/196806) in GitLab 13.9.

You can edit multiple issues across multiple projects when you're in a group.

Prerequisites:

- You must have at least the Reporter role for a group.

To edit multiple issues at the same time:

1. On the top bar, select **Menu > Groups** and find your group.
1. On the left sidebar, select **Issues**.
1. Select **Edit issues**. A sidebar on the right of your screen appears.
1. Select the checkboxes next to each issue you want to edit.
1. From the sidebar, edit the available fields.
1. Select **Update all**.

When bulk editing issues in a group, you can edit the following attributes:

- [Epic](../../group/epics/index.md)
- [Milestone](../milestones/index.md)
- [Iteration](../../group/iterations/index.md)
- [Labels](../labels.md)
- [Health status](#health-status)

## Move an issue

When you move an issue, it's closed and copied to the target project.
The original issue is not deleted. A system note, which indicates
where it came from and went to, is added to both issues.

Be careful when moving an issue to a project with different access rules. Before moving the issue, make sure it does not contain sensitive data.

Prerequisites:

- You must have at least the Reporter role for the project.

To move an issue:

1. Go to the issue.
1. On the right sidebar, select **Move issue**.
1. Search for a project to move the issue to.
1. Select **Move**.

### Bulk move issues **(FREE SELF)**

You can move all open issues from one project to another.

Prerequisites:

- You must have access to the Rails console of the GitLab instance.

To do it:

1. Optional (but recommended). [Create a backup](../../../raketasks/backup_restore.md) before
   attempting any changes in the console.
1. Open the [Rails console](../../../administration/operations/rails_console.md).
1. Run the following script. Make sure to change `project`, `admin_user`, and `target_project` to
   your values.

   ```ruby
   project = Project.find_by_full_path('full path of the project where issues are moved from')
   issues = project.issues
   admin_user = User.find_by_username('username of admin user') # make sure user has permissions to move the issues
   target_project = Project.find_by_full_path('full path of target project where issues moved to')

   issues.each do |issue|
      if issue.state != "closed" && issue.moved_to.nil?
         Issues::MoveService.new(project: project, current_user: admin_user).execute(issue, target_project)
      else
         puts "issue with id: #{issue.id} and title: #{issue.title} was not moved"
      end
   end; nil
   ```

1. To exit the Rails console, enter `quit`.

## Close an issue

When you decide that an issue is resolved or no longer needed, you can close it.
The issue is marked as closed but is not deleted.

Prerequisites:

- You must have at least the Reporter role for the project, be the author of the issue, or be assigned to the issue.

To close an issue, you can do the following:

- At the top of the issue, select **Close issue**.
- In an [issue board](../issue_board.md), drag an issue card from its list into the **Closed** list.

### Reopen a closed issue

Prerequisites:

- You must have at least the Reporter role for the project, be the author of the issue, or be assigned to the issue.

To reopen a closed issue, at the top of the issue, select **Reopen issue**.
A reopened issue is no different from any other open issue.

### Closing issues automatically

You can close issues automatically by using certain words in the commit message or MR description.

If a commit message or merge request description contains text matching the [defined pattern](#default-closing-pattern),
all issues referenced in the matched text are closed when either:

- The commit is pushed to a project's [**default** branch](../repository/branches/default.md).
- The commit or merge request is merged into the default branch.

For example, if you include `Closes #4, #6, Related to #5` in a merge request
description:

- Issues `#4` and `#6` are closed automatically when the MR is merged.
- Issue `#5` is marked as a [related issue](related_issues.md), but it's not closed automatically.

Alternatively, when you [create a merge request from an issue](../merge_requests/getting_started.md#merge-requests-to-close-issues),
it inherits the issue's milestone and labels.

For performance reasons, automatic issue closing is disabled for the very first
push from an existing repository.

#### Default closing pattern

To automatically close an issue, use the following keywords followed by the issue reference.

Available keywords:

- Close, Closes, Closed, Closing, close, closes, closed, closing
- Fix, Fixes, Fixed, Fixing, fix, fixes, fixed, fixing
- Resolve, Resolves, Resolved, Resolving, resolve, resolves, resolved, resolving
- Implement, Implements, Implemented, Implementing, implement, implements, implemented, implementing

Available issue reference formats:

- A local issue (`#123`).
- A cross-project issue (`group/project#123`).
- The full URL of an issue (`https://gitlab.example.com/group/project/issues/123`).

For example:

```plaintext
Awesome commit message

Fix #20, Fixes #21 and Closes group/otherproject#22.
This commit is also related to #17 and fixes #18, #19
and https://gitlab.example.com/group/otherproject/issues/23.
```

The previous commit message closes `#18`, `#19`, `#20`, and `#21` in the project this commit is pushed to,
as well as `#22` and `#23` in `group/otherproject`. `#17` is not closed as it does
not match the pattern.

You can use the closing patterns in multi-line commit messages or one-liners
done from the command line with `git commit -m`.

The default issue closing pattern regex:

```shell
\b((?:[Cc]los(?:e[sd]?|ing)|\b[Ff]ix(?:e[sd]|ing)?|\b[Rr]esolv(?:e[sd]?|ing)|\b[Ii]mplement(?:s|ed|ing)?)(:?) +(?:(?:issues? +)?%{issue_ref}(?:(?: *,? +and +| *,? *)?)|([A-Z][A-Z0-9_]+-\d+))+)
```

#### Disable automatic issue closing

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/19754) in GitLab 12.7.

You can disable the automatic issue closing feature on a per-project basis
in the [project's settings](../settings/index.md).

Prerequisites:

- You must have at least the Maintainer role for the project.

To disable automatic issue closing:

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Settings > Repository**.
1. Expand **Default branch**.
1. Select **Auto-close referenced issues on default branch**.
1. Select **Save changes**.

Referenced issues are still displayed, but are not closed automatically.

The automatic issue closing is disabled by default in a project if the project has the issue tracker
disabled. If you want to enable automatic issue closing, make sure to
[enable GitLab Issues](../settings/index.md#configure-project-visibility-features-and-permissions).

Changing this setting applies only to new merge requests or commits. Already
closed issues remain as they are.
If issue tracking is enabled, disabling automatic issue closing only applies to merge requests
attempting to automatically close issues in the same project.
Merge requests in other projects can still close another project's issues.

#### Customize the issue closing pattern **(FREE SELF)**

Prerequisites:

- You must have [administrator access](../../../administration/index.md) to your GitLab instance.

To change the default issue closing pattern, edit the
[`gitlab.rb` or `gitlab.yml` file](../../../administration/issue_closing_pattern.md)
of your installation.

## Change the issue type

Prerequisites:

- You must be the issue author or have at least the Reporter role for the project, be the author of the issue, or be assigned to the issue.

To change issue type:

1. To the right of the title, select **Edit title and description** (**{pencil}**).
1. Edit the issue and select an issue type from the **Issue type** dropdown list:

   - Issue
   - [Incident](../../../operations/incident_management/index.md)

1. Select **Save changes**.

## Delete an issue

> Deleting from the vertical ellipsis menu [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/299933) in GitLab 14.6.

Prerequisites:

- You must have the Owner role for a project.

To delete an issue:

1. In an issue, select the vertical ellipsis (**{ellipsis_v}**).
1. Select **Delete issue**.

Alternatively:

1. In an issue, select **Edit title and description** (**{pencil}**).
1. Select **Delete issue**.

## Promote an issue to an epic **(PREMIUM)**

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/3777) in GitLab 11.6.
> - Moved from GitLab Ultimate to GitLab Premium in 12.8.
> - Promoting issues to epics via the UI [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/233974) in GitLab 13.6.

You can promote an issue to an [epic](../../group/epics/index.md) in the immediate parent group.

To promote an issue to an epic:

1. In an issue, select the vertical ellipsis (**{ellipsis_v}**).
1. Select **Promote to epic**.

Alternatively, you can use the `/promote` [quick action](../quick_actions.md#issues-merge-requests-and-epics).

Read more about [promoting an issues to epics](../../group/epics/manage_epics.md#promote-an-issue-to-an-epic).

## Add an issue to an iteration **(PREMIUM)**

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/216158) in GitLab 13.2.
> - Moved to GitLab Premium in 13.9.

To add an issue to an [iteration](../../group/iterations/index.md):

1. Go to the issue.
1. On the right sidebar, in the **Iteration** section, select **Edit**.
1. From the dropdown list, select the iteration to associate this issue with.
1. Select any area outside the dropdown list.

Alternatively, you can use the `/iteration` [quick action](../quick_actions.md#issues-merge-requests-and-epics).

## View all issues assigned to you

To view all issues assigned to you:

1. On the top bar, put your cursor in the **Search** box.
1. From the dropdown list, select **Issues assigned to me**.

Or:

- To use a [keyboard shortcut](../../shortcuts.md), press <kbd>Shift</kbd> + <kbd>i</kbd>.
- On the top bar, on the top right, select **{issues}** **Issues**.

## Filter the list of issues

> - Filtering by iterations was [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/118742) in GitLab 13.6.
> - Filtering by iterations was moved from GitLab Ultimate to GitLab Premium in 13.9.
> - Filtering by type was [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/322755) in GitLab 13.10 [with a flag](../../../administration/feature_flags.md) named `vue_issues_list`. Disabled by default.
> - Filtering by type was [enabled on self-managed](https://gitlab.com/gitlab-org/gitlab/-/issues/322755) in GitLab 14.10.
> - Filtering by type is generally available in GitLab 15.1. [Feature flag `vue_issues_list`](https://gitlab.com/gitlab-org/gitlab/-/issues/359966) removed.

To filter the list of issues:

1. Above the list of issues, select **Search or filter results...**.
1. In the dropdown list that appears, select the attribute you want to filter by.
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

### Filter issues by ID

> [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/-/issues/39908) in GitLab 12.1.

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Issues > List**.
1. In the **Search** box, type the issue ID. For example, enter filter `#10` to return only issue 10.

![filter issues by specific ID](img/issue_search_by_id_v15_0.png)

## Copy issue reference

To refer to an issue elsewhere in GitLab, you can use its full URL or a short reference, which looks like
`namespace/project-name#123`, where `namespace` is either a group or a username.

To copy the issue reference to your clipboard:

1. Go to the issue.
1. On the right sidebar, next to **Reference**, select **Copy Reference** (**{copy-to-clipboard}**).

You can now paste the reference into another description or comment.

Read more about issue references in [GitLab-Flavored Markdown](../../markdown.md#gitlab-specific-references).

## Copy issue email address

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/18816) in GitLab 13.8.

You can create a comment in an issue by sending an email.
Sending an email to this address creates a comment that contains the email body.

To learn more about creating comments by sending an email and the necessary configuration, see
[Reply to a comment by sending email](../../discussions/index.md#reply-to-a-comment-by-sending-email).

To copy the issue's email address:

1. Go to the issue.
1. On the right sidebar, next to **Issue email**, select **Copy Reference** (**{copy-to-clipboard}**).

## Real-time sidebar

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/17589) in GitLab 13.3. Disabled by default.
> - [Enabled on GitLab.com](https://gitlab.com/gitlab-com/gl-infra/production/-/issues/3413) in GitLab 13.9.
> - [Enabled on self-managed](https://gitlab.com/gitlab-org/gitlab/-/issues/17589) in GitLab 14.5.
> - [Generally available](https://gitlab.com/gitlab-org/gitlab/-/issues/17589) in GitLab 14.9. Feature flags `real_time_issue_sidebar` and `broadcast_issue_updates` removed.

Assignees in the sidebar are updated in real time.
When you're viewing an issue and somebody changes its assignee,
you can see the change without having to refresh the page.

## Assignee

An issue can be assigned to one or [more users](multiple_assignees_for_issues.md).

The assignees can be changed as often as needed. The idea is that the assignees are
people responsible for an issue.
When an issue is assigned to someone, it appears in their assigned issues list.

If a user is not a member of a project, an issue can only be assigned to them if they create it
themselves or another project member assigns them.

To change the assignee on an issue:

1. Go to your issue.
1. On the right sidebar, in the **Assignee** section, select **Edit**.
1. From the dropdown list, select the user to add as an assignee.
1. Select any area outside the dropdown list.

## Similar issues

To prevent duplication of issues on the same topic, GitLab searches for similar issues
when you create a new issue.

Prerequisites:

- [GraphQL](../../../api/graphql/index.md) must be enabled.

As you type in the title text box of the **New issue** page, GitLab searches titles and descriptions
across all issues in the current project. Only issues you have access to are returned.
Up to five similar issues, sorted by most recently updated, are displayed below the title text box.

## Health status **(ULTIMATE)**

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/36427) in GitLab 12.10.
> - Health status of closed issues [can't be edited](https://gitlab.com/gitlab-org/gitlab/-/issues/220867) in GitLab 13.4 and later.
> - Issue health status visible in issue lists [introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/45141) in GitLab 13.6.
> - [Feature flag removed](https://gitlab.com/gitlab-org/gitlab/-/issues/213567) in GitLab 13.7.

To help you track issue statuses, you can assign a status to each issue.
This status marks issues as progressing as planned or needing attention to keep on schedule.

Prerequisites:

- You must have at least the Reporter role for the project.

To edit health status of an issue:

1. Go to the issue.
1. On the right sidebar, in the **Health status** section, select **Edit**.
1. From the dropdown list, select the status to add to this issue:

   - On track (green)
   - Needs attention (amber)
   - At risk (red)

You can then see the issue's status in the issues list and the epic tree.

After an issue is closed, its health status can't be edited and the **Edit** button becomes disabled
until the issue is reopened.

You can also set and clear health statuses using the `/health_status` and `/clear_health_status`
[quick actions](../quick_actions.md#issues-merge-requests-and-epics).

## Publish an issue **(ULTIMATE)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/30906) in GitLab 13.1.

If a status page application is associated with the project, you can use the `/publish`
[quick action](../quick_actions.md) to publish the issue.

For more information, see [GitLab Status Page](../../../operations/incident_management/status_page.md).

## Issue-related quick actions

You can also use [quick actions](../quick_actions.md#issues-merge-requests-and-epics) to manage issues.

Some actions don't have corresponding UI buttons yet.
You can do the following **only by using quick actions**:

- [Add or remove a Zoom meeting](associate_zoom_meeting.md) (`/zoom` and `/remove_zoom`).
- [Publish an issue](#publish-an-issue) (`/publish`).
- Clone an issue to the same or another project (`/clone`).
- Close an issue and mark as a duplicate of another issue (`/duplicate`).
- Copy labels and milestone from another merge request in the project (`/copy_metadata`).
