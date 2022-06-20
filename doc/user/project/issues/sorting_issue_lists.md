---
stage: Plan
group: Project Management
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Sorting and ordering issue lists **(FREE)**

You can sort a list of issues several ways.
The available sorting options can change based on the context of the list.

## Sorting by blocking issues **(PREMIUM)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/34247/) in GitLab 13.7.

When you sort by **Blocking**, the issue list changes to sort descending by the
number of issues each issue is [blocking](related_issues.md#blocking-issues).

## Sorting by created date

When you sort by **Created date**, the issue list changes to sort descending by the issue
creation date. Issues created most recently are first.

## Sorting by due date

When you sort by **Due date**, the issue list changes to sort ascending by the issue
[due date](due_dates.md). Issues with the earliest due date are first,
and issues without a due date are last.

## Sorting by label priority

When you sort by **Label priority**, the issue list changes to sort descending.
Issues with the highest priority label are first, then all other issues.

Ties are broken arbitrarily. Only the highest prioritized label is checked,
and labels with a lower priority are ignored.
For more information, see [issue 14523](https://gitlab.com/gitlab-org/gitlab/-/issues/14523).

To learn how to change label priority, see [Label priority](../labels.md#set-label-priority).

## Sorting by updated date

When you sort by **Updated date**, the issue list changes to sort by the time of a last
update. Issues changed the most recently are shown first.

## Manual sorting

> [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/-/issues/62178) in GitLab 12.2.

When you sort by **Manual** order, you can change
the order by dragging and dropping the issues. The changed order persists, and
everyone who visits the same list sees the updated issue order, with some exceptions.

Each issue is assigned a relative order value, representing its relative
order with respect to the other issues on the list. When you drag-and-drop reorder
an issue, its relative order value changes.

In addition, any time an issue appears in a manually sorted list,
the updated relative order value is used for the ordering.
So, if anyone drags issue `A` above issue `B` in your GitLab instance,
this ordering is maintained whenever they appear together in any list.

This ordering also affects [issue boards](../issue_board.md#ordering-issues-in-a-list).
Changing the order in an issue list changes the ordering in an issue board,
and the other way around.

## Sorting by milestone due date

When you sort by **Milestone due date**, the issue list changes to sort ascending by the
assigned milestone due date. Issues with milestones with the earliest due date are first,
then issues with a milestone without a due date.

## Sorting by popularity

When you sort by **Popularity**, the issue order changes to sort descending by the
number of upvotes ([awarded](../../award_emojis.md) a "thumbs up" emoji)
on each issue. You can use this to identify issues that are in high demand.

## Sorting by priority

When you sort by **Priority**, the issue order changes to sort in this order:

1. Issues with milestones that have due dates, where the soonest assigned milestone is listed first.
1. Issues with milestones with no due dates.
1. Issues with a higher priority label.
1. Issues without a prioritized label.

Ties are broken arbitrarily.

To learn how to change label priority, see [Label priority](../labels.md#set-label-priority).

## Sorting by title

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/67234) in GitLab 14.3.

When you sort by **Title**, the issue order changes to sort alphabetically by the issue
title in this order:

- Emoji
- Special characters
- Numbers
- Letters: first Latin, then accented (for example, `ö`)

## Sorting by weight

When you sort by **Weight**, the issue list changes to sort ascending by the
[issue weight](issue_weight.md).
Issues with lowest weight are first, and issues without a weight are last.
