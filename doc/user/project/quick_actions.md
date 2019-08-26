---
type: reference
---

# GitLab Quick Actions

Quick actions are textual shortcuts for common actions on issues, epics, merge requests,
and commits that are usually done by clicking buttons or dropdowns in GitLab's UI.
You can enter these commands while creating a new issue or merge request, or
in comments of issues, epics, merge requests, and commits. Each command should be
on a separate line in order to be properly detected and executed. Once executed,

> From [GitLab 12.1](https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/26672), an alert is displayed when a quick action is successfully applied.

## Quick Actions for issues and merge requests

The following quick actions are applicable to both issues and merge requests threads,
discussions, and descriptions:

| Command                    | Action                         | Issue | Merge request |
|:---------------------------|:------------------------------ |:------|:--------------|
| `/tableflip <Comment>`     | Append the comment with `(╯°□°)╯︵ ┻━┻` | ✓ | ✓        |
| `/shrug <Comment>`         | Append the comment with `¯\＿(ツ)＿/¯` | ✓ | ✓         |
| `/todo`                    | Add a To Do                    | ✓     | ✓             |
| `/done`                    | Mark To Do as done             | ✓     | ✓             |
| `/subscribe`               | Subscribe                      | ✓     | ✓             |
| `/unsubscribe`             | Unsubscribe                    | ✓     | ✓             |
| `/close`                   | Close                          | ✓     | ✓             |
| `/reopen`                  | Reopen                         | ✓     | ✓             |
| `/title <New title>`       | Change title                   | ✓     |  ✓            |
| `/award :emoji:`           | Toggle emoji award             | ✓     | ✓             |
| `/assign me`               | Assign yourself                | ✓     | ✓             |
| `/assign @user`            | Assign one user                | ✓     | ✓             |
| `/assign @user1 @user2`    | Assign multiple users **(STARTER)** | ✓ | ✓            |
| `/unassign @user1 @user2`  | Remove assignee(s) **(STARTER)** | ✓     | ✓             |
| `/reassign @user1 @user2`  | Change assignee **(STARTER)**  | ✓     | ✓             |
| `/unassign`                | Remove current assignee        | ✓     | ✓             |
| `/milestone %milestone`    | Set milestone                  | ✓     | ✓             |
| `/remove_milestone`        | Remove milestone               | ✓     | ✓             |
| `/label ~label1 ~label2`   | Add label(s). Label names can also start without ~ but mixed syntax is not supported.                   | ✓     | ✓             |
| `/unlabel ~label1 ~label2` | Remove all or specific label(s)| ✓     | ✓             |
| `/relabel ~label1 ~label2` | Replace existing label(s) with those specified | ✓     | ✓             |
| `/copy_metadata <#issue>` | Copy labels and milestone from another issue in the project | ✓     | ✓             |
| `/copy_metadata <!merge_request>` | Copy labels and milestone from another merge request in the project | ✓     | ✓             |
| `/estimate <1w 3d 2h 14m>` | Set time estimate | ✓     | ✓             |
| `/remove_estimate`       | Remove time estimate             | ✓     | ✓             |
| `/spend <time(1h 30m)> <date(YYYY-MM-DD)>` | Add spent time; optionally, specify the date that time was spent on | ✓     | ✓             |
| `/spend <time(-1h 5m)> <date(YYYY-MM-DD)>` | Subtract spent time; optionally, specify the date that time was spent on | ✓     | ✓             |
| `/remove_time_spent`       | Remove time spent              | ✓     | ✓             |
| `/lock`                    | Lock the thread                | ✓     | ✓             |
| `/unlock`                  | Unlock the thread              | ✓     | ✓             |
| `/due <date>` | Set due date. Examples of valid `<date>` include `in 2 days`, `this Friday` and `December 31st`. | ✓ | |
| `/remove_due_date`         | Remove due date                | ✓     |               |
| `/weight <value>` | Set weight. Valid options for `<value>` include `0`, `1`, `2`, etc. **(STARTER)**       | ✓     |               |
| `/clear_weight`            | Clears weight **(STARTER)**    | ✓     |               |
| `/epic <epic>` | Add to epic `<epic>`. The `<epic>` value should be in the format of `&epic`, `group&epic` or `epic-URL`. **(ULTIMATE)** | ✓ |             |
| `/remove_epic`             | Removes from epic **(ULTIMATE)** | ✓   |               |
| `/promote`                 | Promote issue to epic **(ULTIMATE)** | ✓   |               |
| `/confidential`            | Make confidential              | ✓     |               |
| `/duplicate <#issue>`        | Mark this issue as a duplicate of another issue | ✓    |
| `/move <path/to/project>`    | Move this issue to another project | ✓ |               |
| `/target_branch <Local branch Name>` | Set target branch    |       | ✓             |
| `/wip`                     | Toggle the Work In Progress status |   | ✓             |
| `/approve`                 | Approve the merge request      |       | ✓             |
| `/merge`                   | Merge (when pipeline succeeds) |       | ✓             |
| `/create_merge_request <branch name>` | Create a new merge request starting from the current issue | ✓ | |
| `/relate #issue1 #issue2`  | Mark issues as related **(STARTER)** | ✓     |               |

## Autocomplete characters

Many quick actions require a parameter, for example: username, milestone, and
label. [Autocomplete characters](autocomplete_characters.md) can make it easier
to enter a parameter, compared to selecting items from a list.

## Quick actions parameters

The easiest way to set parameters for quick actions is to use autocomplete. If
you manually enter a parameter, it must be enclosed in double quotation marks
(`"`), unless it contains only:

1. ASCII letters.
1. Numerals.
1. Underscore, hyphen, question mark, dot, and ampersand.

Parameters are also case-sensitive. Autocomplete handles this, and the insertion
of quotation marks, automatically.

## Quick actions for commit messages

The following quick actions are applicable for commit messages:

| Command                 | Action                                    |
|:------------------------|:------------------------------------------|
| `/tag v1.2.3 <message>` | Tags this commit with an optional message |

## Quick actions for Epics **(ULTIMATE)**

The following quick actions are applicable for epics threads and description:

| Command                    | Action                                  |
|:---------------------------|:----------------------------------------|
| `/tableflip <Comment>`     | Append the comment with `(╯°□°)╯︵ ┻━┻` |
| `/shrug <Comment>`         | Append the comment with `¯\＿(ツ)＿/¯`  |
| `/todo`                    | Add a To Do                              |
| `/done`                    | Mark To Do as done                       |
| `/subscribe`               | Subscribe                               |
| `/unsubscribe`             | Unsubscribe                             |
| `/close`                   | Close                                   |
| `/reopen`                  | Reopen                                  |
| `/title <New title>`       | Change title                            |
| `/award :emoji:`           | Toggle emoji award                      |
| `/label ~label1 ~label2`   | Add label(s)                            |
| `/unlabel ~label1 ~label2` | Remove all or specific label(s)         |
| `/relabel ~label1 ~label2` | Replace existing label(s) with those specified |
| `/child_epic <epic>` | Adds child epic to `<epic>`. The `<epic>` value should be in the format of `&epic`, `group&epic` or `epic-URL`. ([Introduced in GitLab 12.0](https://gitlab.com/gitlab-org/gitlab-ee/issues/7330)) **(ULTIMATE)**|
| `/remove_child_epic <epic>` | Removes child epic from `<epic>`. The `<epic>` value should be in the format of `&epic`, `group&epic` or `epic-URL`. ([Introduced in GitLab 12.0](https://gitlab.com/gitlab-org/gitlab-ee/issues/7330)) **(ULTIMATE)** |
| `/parent_epic <epic>` | Sets parent epic to `<epic>`. The `<epic>` value should be in the format of `&epic`, `group&epic` or `epic-URL`. ([introduced in GitLab 12.1](https://gitlab.com/gitlab-org/gitlab-ee/issues/10556)) **(ULTIMATE)** |
| `/remove_parent_epic` | Removes parent epic from epic ([introduced in GitLab 12.1](https://gitlab.com/gitlab-org/gitlab-ee/issues/10556)) |

<!-- ## Troubleshooting

Include any troubleshooting steps that you can foresee. If you know beforehand what issues
one might have when setting this up, or when something is changed, or on upgrading, it's
important to describe those, too. Think of things that may go wrong and include them here.
This is important to minimize requests for support, and to avoid doc comments with
questions that you know someone might ask.

Each scenario can be a third-level heading, e.g. `### Getting error message X`.
If you have none to add when creating a doc, leave this section in place
but commented out to help encourage others to add to it in the future. -->
