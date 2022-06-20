---
stage: Create
group: Source Code
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
type: reference, concepts
---

# Merge request approvals **(PREMIUM SELF)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/39060) in GitLab 12.8.

Merge request approval rules prevent users from overriding certain settings on the project level.
When enabled at the instance level, these settings [cascade](../project/merge_requests/approvals/settings.md#settings-cascading)
and can no longer be changed:

- In projects.
- In groups. Cascading to groups was [enabled by default](https://gitlab.com/gitlab-org/gitlab/-/issues/285410)
  in GitLab 14.5.

To enable merge request approval settings for an instance:

1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **{push-rules}** **Push Rules**, and expand **Merge request approvals**.
1. Choose the required options.
1. Click **Save changes**.

## Available rules

Merge request approval settings that can be set at an instance level are:

- **Prevent approval by author**. Prevents project maintainers from allowing request authors to
  merge their own merge requests.
- **Prevent approvals by users who add commits**. Prevents project maintainers from allowing users
  to approve merge requests if they have submitted any commits to the source branch.
- **Prevent editing approval rules in projects and merge requests**. Prevents users from modifying
  the approvers list in project settings or in individual merge requests.

See also the following, which are affected by instance-level rules:

- [Project merge request approval rules](../project/merge_requests/approvals/index.md).
- [Group merge request approval settings](../group/index.md#group-approval-settings) available in GitLab 13.9 and later.
