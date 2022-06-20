---
type: reference, howto
stage: Manage
group: Compliance
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Compliance report **(ULTIMATE)**

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/36524) in GitLab 12.8 as Compliance Dashboard.
> - [Renamed](https://gitlab.com/gitlab-org/gitlab/-/issues/299360) to compliance report in GitLab 14.2.
> - [Replaced](https://gitlab.com/groups/gitlab-org/-/epics/5237) by merge request violations in GitLab 14.6 [with a flag](../../../administration/feature_flags.md) named `compliance_violations_report`. Disabled by default.
> - GraphQL API [introduced](https://gitlab.com/groups/gitlab-org/-/epics/7222) in GitLab 14.9.
> - [Generally available](https://gitlab.com/groups/gitlab-org/-/epics/5237) in GitLab 14.10. [Feature flag `compliance_violations_report`](https://gitlab.com/gitlab-org/gitlab/-/issues/346266) removed.

Compliance report gives you the ability to see a group's merge request activity. It provides a
high-level view for all projects in the group. For example, code approved for merging into
production.

You can use the report to get:

- A list of compliance violations from all merged merge requests within the group.
- The reason and severity of each compliance violation.
- A link to the merge request that caused each compliance violation.

## View the compliance report for a group

Prerequisites:

- You must be an administrator or have the Owner role for the group.

To view the compliance report:

1. On the top bar, select **Menu > Groups** and find your group.
1. On the left sidebar, select **Security & Compliance > Compliance report**.

### Severity levels scale

The following is a list of available violation severity levels, ranked from most to least severe:

| Icon                                          | Severity level |
|:----------------------------------------------|:---------------|
| **{severity-critical, 18, gl-fill-red-800}**  | Critical       |
| **{severity-high, 18, gl-fill-red-600}**      | High           |
| **{severity-medium, 18, gl-fill-orange-400}** | Medium         |
| **{severity-low, 18, gl-fill-orange-300}**    | Low            |
| **{severity-info, 18, gl-fill-blue-400}**     | Info           |

### Violation types

The following is a list of violations that are either:

- Already available.
- Aren't available, but which we are tracking in issues.

| Violation                            | Severity level  | Category                                                                               | Description                                                                                                                                                                                      | Availability                                                                    |
|:-------------------------------------|:----------------|:---------------------------------------------------------------------------------------|:-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:--------------------------------------------------------------------------------|
| Author approved merge request        | High            | [Separation of duties](#separation-of-duties)                                          | The author of the merge request approved their own merge request. [Learn more](../../project/merge_requests/approvals/settings.md#prevent-approval-by-author).                                   | [Available in GitLab 14.10](https://gitlab.com/groups/gitlab-org/-/epics/6870)  |
| Committers approved merge request    | High            | [Separation of duties](#separation-of-duties)                                          | The committers of the merge request approved the merge request they contributed to. [Learn more](../../project/merge_requests/approvals/settings.md#prevent-approvals-by-users-who-add-commits). | [Available in GitLab 14.10](https://gitlab.com/groups/gitlab-org/-/epics/6870)  |
| Fewer than two approvals             | High            | [Separation of duties](#separation-of-duties)                                          | The merge request was merged with fewer than two approvals. [Learn more](../../project/merge_requests/approvals/rules.md).                                                                       | [Available in GitLab 14.10](https://gitlab.com/groups/gitlab-org/-/epics/6870) |
| Pipeline failed                      | Medium          | [Pipeline results](../../../ci/pipelines/index.md)                                     | The merge requests pipeline failed and was merged.                                                                                                                                               | [Unavailable](https://gitlab.com/gitlab-org/gitlab/-/issues/346011)             |
| Pipeline passed with warnings        | Info            | [Pipeline results](../../../ci/pipelines/index.md)                                     | The merge request pipeline passed with warnings and was merged.                                                                                                                                  | [Unavailable](https://gitlab.com/gitlab-org/gitlab/-/issues/346011)             |
| Code coverage down more than 10%     | High            | [Code coverage](../../../ci/pipelines/settings.md#merge-request-test-coverage-results) | The code coverage report for the merge request indicates a reduction in coverage of more than 10%.                                                                                               | [Unavailable](https://gitlab.com/gitlab-org/gitlab/-/issues/346011)             |
| Code coverage down between 5% to 10% | Medium          | [Code coverage](../../../ci/pipelines/settings.md#merge-request-test-coverage-results) | The code coverage report for the merge request indicates a reduction in coverage of between 5% to 10%.                                                                                           | [Unavailable](https://gitlab.com/gitlab-org/gitlab/-/issues/346011)             |
| Code coverage down between 1% to 5%  | Low             | [Code coverage](../../../ci/pipelines/settings.md#merge-request-test-coverage-results) | The code coverage report for the merge request indicates a reduction in coverage of between 1% to 5%.                                                                                            | [Unavailable](https://gitlab.com/gitlab-org/gitlab/-/issues/346011)             |
| Code coverage down less than 1%      | Info            | [Code coverage](../../../ci/pipelines/settings.md#merge-request-test-coverage-results) | The code coverage report for the merge request indicates a reduction in coverage of less than 1%.                                                                                                | [Unavailable](https://gitlab.com/gitlab-org/gitlab/-/issues/346011)             |

## Merge request drawer

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/299357) in GitLab 14.1.

When you select a row, a drawer is shown that provides further details about the merge
request:

- Project name and [compliance framework label](../../project/settings/index.md#compliance-frameworks),
  if the project has one assigned.
- Link to the merge request.
- The merge request's branch path in the format `[source] into [target]`.
- A list of users that committed changes to the merge request.
- A list of users that commented on the merge request.
- A list of users that approved the merge request.
- The user that merged the merge request.

## Separation of duties

We support a separation of duties policy between users who create and approve merge requests.
Our criteria for the separation of duties is as follows:

- [A merge request author is **not** allowed to approve their merge request](../../project/merge_requests/approvals/settings.md#prevent-approval-by-author)
- [A merge request committer is **not** allowed to approve a merge request they have added commits to](../../project/merge_requests/approvals/settings.md#prevent-approvals-by-users-who-add-commits)
- [The minimum number of approvals required to merge a merge request is **at least** two](../../project/merge_requests/approvals/rules.md)

## Chain of Custody report

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/213364) in GitLab 13.3.

The Chain of Custody report allows customers to export a list of merge commits within the group.
The data provides a comprehensive view with respect to merge commits. It includes the merge commit SHA,
merge request author, merge request ID, merge user, pipeline ID, group name, project name, and merge request approvers.
Depending on the merge strategy, the merge commit SHA can be a merge commit, squash commit, or a diff head commit.

To download the Chain of Custody report:

1. On the top bar, select **Menu > Groups** and find your group.
1. On the left sidebar, select **Security & Compliance > Compliance report**.
1. Select **List of all merge commits**.

### Commit-specific Chain of Custody Report

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/267629) in GitLab 13.6.

You can generate a commit-specific Chain of Custody report for a given commit SHA.

1. On the top bar, select **Menu > Groups** and find your group.
1. On the left sidebar, select **Security & Compliance > Compliance report**.
1. At the top of the compliance report, to the right of **List of all merge commits**, select the down arrow (**{angle-down}**).
1. Enter the merge commit SHA, and then select **Export commit custody report**.
   SHA and then select **Export commit custody report**.

NOTE:
The Chain of Custody report download is a CSV file, with a maximum size of 15 MB.
The remaining records are truncated when this limit is reached.
