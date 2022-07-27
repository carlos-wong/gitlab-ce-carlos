---
type: howto
stage: Plan
group: Product Planning
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Manage epics **(PREMIUM)**

This page collects instructions for all the things you can do with [epics](index.md) or in relation
to them.

## Create an epic

> - The New Epic form [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/211533) in GitLab 13.2.
> - In [GitLab 13.7](https://gitlab.com/gitlab-org/gitlab/-/issues/229621) and later, the New Epic button on the Epics list opens the New Epic form.
> - In [GitLab 13.9](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/45948) and later, you can create a new epic from an empty roadmap.

Prerequisites:

- You must have at least the Reporter role for the epic's group.

To create an epic in the group you're in:

1. Get to the New Epic form:
   - Go to your group and from the left sidebar select **Epics**. Then select **New epic**.
   - From an epic in your group, select **New epic**.
   - From anywhere, in the top menu, select **New...** (**{plus-square}**) **> New epic**.
   - In an empty [roadmap](../roadmap/index.md), select **New epic**.

1. Enter a title.
1. Complete the fields.
   - Enter a description.
   - To [make the epic confidential](#make-an-epic-confidential), select the checkbox under **Confidentiality**.
   - Choose labels.
   - Select a start and due date, or [inherit](#start-and-due-date-inheritance) them.
   - Select a [color](#epic-color).
1. Select **Create epic**.

The newly created epic opens.

### Start and due date inheritance

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/7332) in GitLab 12.5 to replace **From milestones**.

If you select **Inherited**:

- For the **start date**: GitLab scans all child epics and issues assigned to the epic,
  and sets the start date to match the earliest start date found in the child epics or the milestone
  assigned to the issues.
- For the **due date**: GitLab scans all child epics and issues assigned to the epic,
  and sets the due date to match the latest due date found in the child epics or the milestone
  assigned to the issues.

These are dynamic dates and recalculated if any of the following occur:

- A child epic's dates change.
- Milestones are reassigned to an issue.
- A milestone's dates change.
- Issues are added to, or removed from, the epic.

Because the epic's dates can inherit dates from its children, the start date and due date propagate from the bottom to the top.
If the start date of a child epic on the lowest level changes, that becomes the earliest possible start date for its parent epic.
The parent epic's start date then reflects this change and propagates upwards to the top epic.

### Epic color

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/79940) in GitLab 14.9 [with a flag](../../../administration/feature_flags.md) named `epic_color_highlight`. Disabled by default.

FLAG:
On self-managed GitLab, by default this feature is not available. To make it available per group, ask an administrator to [enable the feature flag](../../../administration/feature_flags.md) named `epic_color_highlight`.
On GitLab.com, this feature is available but can be configured by GitLab.com administrators only.
The feature is not ready for production use.

When you create or edit an epic, you can select its color.
An epic's color is shown in [roadmaps](../roadmap/index.md), and [epic boards](epic_boards.md).

## Edit an epic

After you create an epic, you can edit the following details:

- Title
- Description
- Start date
- Due date
- Labels
- [Color](#epic-color)

Prerequisites:

- You must have at least the Reporter role for the epic's group.

To edit an epic's title or description:

1. Select **Edit title and description** **{pencil}**.
1. Make your changes.
1. Select **Save changes**.

To edit an epic's start date, due date, or labels:

1. Next to each section in the right sidebar, select **Edit**.
1. Select the dates or labels for your epic.

### Reorder list items in the epic description

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/15260) in GitLab 15.1.

When you view an epic that has a list in the description, you can also reorder the list items.

Prerequisites:

- You must have at least the Reporter role for the project, be the author of the epic, or be
  assigned to the epic.
- The epic's description must have an [ordered, unordered](../../markdown.md#lists), or
  [task](../../markdown.md#task-lists) list.

To reorder list items, when viewing an epic:

1. Hover over the list item row to make the drag icon (**{drag-vertical}**) visible.
1. Select and hold the drag icon.
1. Drag the row to the new position in the list.
1. Release the drag icon.

## Bulk edit epics

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/7250) in GitLab 12.2.

Users with at least the Reporter role can manage epics.

When bulk editing epics in a group, you can edit their labels.

Prerequisites:

- You must have at least the Reporter role for the parent epic's group.

To update multiple epics at the same time:

1. In a group, go to **Epics > List**.
1. Select **Edit epics**. A sidebar on the right appears with editable fields.
1. Select the checkboxes next to each epic you want to edit.
1. Select the appropriate fields and their values from the sidebar.
1. Select **Update all**.

## Delete an epic

Prerequisites:

- You must have the Owner role for the epic's group.

To delete the epic:

1. Select **Edit title and description** **{pencil}**.
1. Select **Delete**. A modal appears to confirm your action.

Deleting an epic releases all existing issues from their associated epic in the system.

WARNING:
If you delete an epic, all its child epics and their descendants are deleted as well. If needed, you can [remove child epics](#remove-a-child-epic-from-a-parent-epic) from the parent epic before you delete it.

## Close an epic

Prerequisites:

- You must have at least the Reporter role for the epic's group.

Whenever you decide that there is no longer need for that epic,
close the epic by:

- Selecting **Close epic**.

  ![close epic - button](img/button_close_epic.png)

- Using the `/close` [quick action](../../project/quick_actions.md).

## Reopen a closed epic

You can reopen an epic that was closed.

Prerequisites:

- You must have at least the Reporter role for the epic's group.

To do so, either:

- Select **Reopen epic**.

  ![reopen epic - button](img/button_reopen_epic.png)

- Use the `/reopen` [quick action](../../project/quick_actions.md).

## Go to an epic from an issue

If an issue belongs to an epic, you can go to the parent epic with the
link in the right sidebar.

![containing epic](img/containing_epic.png)

## View epics list

In a group, the left sidebar displays the total count of open epics.
This number indicates all epics associated with the group and its subgroups, including epics you
might not have permission to view.

Prerequisites:

- You must be a member of either:
  - The group
  - A project in the group
  - A project in one of the group's subgroups

To view epics in a group:

1. On the top bar, select **Menu > Groups** and find your group.
1. On the left sidebar, select **Epics**.

### Cached epic count

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/299540) in GitLab 13.11 [with a flag](../../../administration/feature_flags.md) named `cached_sidebar_open_epics_count`. Enabled by default.
> - Enabled on self-managed and on GitLab.com in GitLab 14.0. [Feature flag `cached_sidebar_open_epics_count`](https://gitlab.com/gitlab-org/gitlab/-/issues/327320) removed.

The total count of open epics displayed in the sidebar is cached if higher
than 1000. The cached value is rounded to thousands or millions and updated every 24 hours.

## Filter the list of epics

> - Filtering by epics was [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/195704) in GitLab 12.9.
> - Filtering by child epics was [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/9029) in GitLab 13.0.
> - Filtering by the user's reaction emoji [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/325630) in GitLab 13.11.
> - Sorting by epic titles [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/331625) in GitLab 14.1.
> - Filtering by milestone and confidentiality [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/268372) in GitLab 14.2 [with a flag](../../../administration/feature_flags.md) named `vue_epics_list`. Disabled by default.
> - [Enabled on GitLab.com and self-managed](https://gitlab.com/gitlab-org/gitlab/-/issues/276189) in GitLab 14.7.
> - [Feature flag `vue_epics_list`](https://gitlab.com/gitlab-org/gitlab/-/issues/327320) removed in GitLab 14.8.

You can filter the list of epics by:

- Title or description
- Author name / username
- Labels
- Milestones
- Confidentiality
- Reaction emoji

![epics filter](img/epics_filter_v14_7.png)

To filter:

1. On the top bar, select **Menu > Groups** and find your group.
1. On the left sidebar, select **Epics**.
1. Select the field **Search or filter results**.
1. From the dropdown menu, select the scope or enter plain text to search by epic title or description.
1. Press <kbd>Enter</kbd> on your keyboard. The list is filtered.

## Sort the list of epics

You can sort the epics list by:

- Start date
- Due date
- Title

Each option contains a button that can toggle the order between **Ascending** and **Descending**.
The sort option and order is saved and used wherever you browse epics, including the
[Roadmap](../roadmap/index.md).

![epics sort](img/epics_sort_14_7.png)

## Change activity sort order

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/214364) in GitLab 13.2.

You can reverse the default order and interact with the activity feed sorted by most recent items
at the top. Your preference is saved via local storage and automatically applied to every epic and issue
you view.

To change the activity sort order, select the **Oldest first** dropdown menu and select either oldest
or newest items to be shown first.

![Issue activity sort order dropdown button](img/epic_activity_sort_order_v13_2.png)

## Make an epic confidential

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/213068) in GitLab 13.0 behind a feature flag, disabled by default.
> - [Became enabled by default](https://gitlab.com/gitlab-org/gitlab/-/issues/224513) in GitLab 13.2.
> - You can [use the Confidentiality option in the epic sidebar](https://gitlab.com/gitlab-org/gitlab/-/issues/197340) in GitLab 13.3 and later.

If you're working on items that contain private information, you can make an epic confidential.

NOTE:
A confidential epic can only contain [confidential issues](../../project/issues/confidential_issues.md)
and confidential child epics. However, merge requests are public, if created in a public project.
Read [Merge requests for confidential issues](../../project/merge_requests/confidential.md)
to learn how to create a confidential merge request.

Prerequisites:

- You must have at least the Reporter role for the epic's group.

To make an epic confidential:

- **When creating an epic:** select the checkbox under **Confidentiality**.
- **In an existing epic:** on the right sidebar, select **Edit** next to **Confidentiality**, and then
  select **Turn on**.

## Manage issues assigned to an epic

This section collects instructions for all the things you can do with [issues](../../project/issues/index.md)
in relation to epics.

### View issues assigned to an epic

On the **Epics and Issues** tab, you can see epics and issues assigned to this epic.
Only epics and issues that you can access show on the list.

You can always view the issues assigned to the epic if they are in the group's child project.
It's possible because the visibility setting of a project must be the same as or less restrictive than
of its parent group.

### View count of issues in an epic

On the **Epics and Issues** tab, under each epic name, hover over the total counts.

The number indicates all epics associated with the project, including issues
you might not have permission to.

### Add a new issue to an epic

You can add an existing issue to an epic, or create a new issue that's
automatically added to the epic.

#### Add an existing issue to an epic

Existing issues that belong to a project in an epic's group, or any of the epic's
subgroups, are eligible to be added to the epic. Newly added issues appear at the top of the list of
issues in the **Epics and Issues** tab.

An epic contains a list of issues and an issue can be associated with at most one epic.
When you add a new issue that's already linked to an epic, the issue is automatically unlinked from its
current parent.

Prerequisites:

- You must have at least the Reporter role for the epic's group.
- You must be able to [edit the issue](../../project/issues/managing_issues.md#edit-an-issue).

To add an existing issue to an epic:

1. On the epic's page, under **Epics and Issues**, select **Add**.
1. Select **Add an existing issue**.
1. Identify the issue to be added, using either of the following methods:
   - Paste the link of the issue.
   - Search for the desired issue by entering part of the issue's title, then selecting the desired
     match ([introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/9126) in GitLab 12.5).

   If there are multiple issues to be added, press <kbd>Space</kbd> and repeat this step.
1. Select **Add**.

#### Create an issue from an epic

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/5419) in GitLab 12.7.

Creating an issue from an epic enables you to maintain focus on the broader context of the epic
while dividing work into smaller parts.

Prerequisites:

- You must have at least the Reporter role for the epic's group.

To create an issue from an epic:

1. On the epic's page, under **Epics and Issues**, select **Add**.
1. Select **Add a new issue**.
1. Under **Title**, enter the title for the new issue.
1. From the **Project** dropdown list, select the project in which the issue should be created.
1. Select **Create issue**.

The new issue is assigned to the epic.

### Remove an issue from an epic

You can remove issues from an epic when you're on the epic's details page.
After you remove an issue from an epic, the issue is no longer associated with this epic.

Prerequisites:

- You must have at least the Reporter role for the epic's group.
- You must be able to [edit the issue](../../project/issues/managing_issues.md#edit-an-issue).

To remove an issue from an epic:

1. Next to the issue you want to remove, select **Remove** (**{close}**).
   The **Remove issue** warning appears.
1. Select **Remove**.

![List of issues assigned to an epic](img/issue_list_v13_1.png)

### Reorder issues assigned to an epic

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/9367) in GitLab 12.5.

New issues appear at the top of the list in the **Epics and Issues** tab.
You can reorder the list of issues by dragging them.

Prerequisites:

- You must have at least the Reporter role for the epic's group.

To reorder issues assigned to an epic:

1. Go to the **Epics and Issues** tab.
1. Drag issues into the desired order.

### Move issues between epics **(ULTIMATE)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/33039) in GitLab 13.0.

New issues appear at the top of the list in the **Epics and Issues**
tab. You can move issues from one epic to another.

Prerequisites:

- You must have at least the Reporter role for the epic's group.
- You must be able to [edit the issue](../../project/issues/managing_issues.md#edit-an-issue).

To move an issue to another epic:

1. Go to the **Epics and Issues** tab.
1. Drag issues into the desired parent epic in the visible hierarchy.

### Promote an issue to an epic

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/3777) in GitLab 11.6.
> - [Moved](https://gitlab.com/gitlab-org/gitlab/-/issues/37081) from GitLab Ultimate to GitLab Premium in 12.8.

Prerequisites:

- The project to which the issue belongs must be in a group.
- You must have at least the Reporter role the project's immediate parent group.
- You must either:
  - Have at least the Reporter role for the project.
  - Be the author of the issue.
  - Be assigned to the issue.

You can promote an issue to an epic with the `/promote`
[quick action](../../project/quick_actions.md#issues-merge-requests-and-epics).

NOTE:
Promoting a confidential issue to an epic makes all information
related to the issue public as epics are public to group members.

When an issue is promoted to an epic:

- If the issue was confidential, an additional warning is displayed first.
- An epic is created in the same group as the project of the issue.
- Subscribers of the issue are notified that the epic was created.

The following issue metadata is copied to the epic:

- Title, description, activity/comment thread.
- Upvotes and downvotes.
- Participants.
- Group labels that the issue already has.
- Parent epic.

### Use an epic template for repeating issues

You can create a spreadsheet template to manage a pattern of consistently repeating issues.

<i class="fa fa-youtube-play youtube" aria-hidden="true"></i>
For an introduction to epic templates, see [GitLab Epics and Epic Template Tip](https://www.youtube.com/watch?v=D74xKFNw8vg).

For more on epic templates, see [Epic Templates - Repeatable sets of issues](https://about.gitlab.com/handbook/marketing/strategic-marketing/getting-started/104/).

## Multi-level child epics **(ULTIMATE)**

You can add any epic that belongs to a group or subgroup of the parent epic's group.
New child epics appear at the top of the list of epics in the **Epics and Issues** tab.

When you add an epic that's already linked to a parent epic, the link to its current parent is removed.

Epics can contain multiple nested child epics, up to a total of seven levels deep.

### Add a child epic to an epic

Prerequisites:

- You must have at least the Reporter role for the parent epic's group.

To add a child epic to an epic:

1. Select **Add**.
1. Select **Add a new epic**.
1. Identify the epic to be added, using either of the following methods:
   - Paste the link of the epic.
   - Search for the desired issue by entering part of the epic's title, then selecting the desired
     match ([introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/9126) in GitLab 12.5).

   If there are multiple epics to be added, press <kbd>Space</kbd> and repeat this step.
1. Select **Add**.

### Move child epics between epics

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/33039) in GitLab 13.0.

New child epics appear at the top of the list in the **Epics and Issues** tab.
You can move child epics from one epic to another.
When you add a new epic that's already linked to a parent epic, the link to its current parent is removed.
Issues and child epics cannot be intermingled.

Prerequisites:

- You must have at least the Reporter role for the parent epic's group.

To move child epics to another epic:

1. Go to the **Epics and Issues** tab.
1. Drag epics into the desired parent epic.

### Reorder child epics assigned to an epic

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/9367) in GitLab 12.5.

New child epics appear at the top of the list in the **Epics and Issues** tab.
You can reorder the list of child epics.

Prerequisites:

- You must have at least the Reporter role for the parent epic's group.

To reorder child epics assigned to an epic:

1. Go to the **Epics and Issues** tab.
1. Drag epics into the desired order.

### Remove a child epic from a parent epic

Prerequisites:

- You must have at least the Reporter role for the parent epic's group.

To remove a child epic from a parent epic:

1. Select **Remove** (**{close}**) in the parent epic's list of epics.
   The **Remove epic** warning appears.
1. Select **Remove**.
