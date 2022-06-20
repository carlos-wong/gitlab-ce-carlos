---
stage: Create
group: Source Code
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Protected branches **(FREE)**

In GitLab, [permissions](../permissions.md) are fundamentally defined around the
idea of having read or write permission to the repository and branches. To impose
further restrictions on certain branches, they can be protected.

The default branch for your repository is protected by default.

## Who can modify a protected branch

When a branch is protected, the default behavior enforces these restrictions on the branch.

| Action                   | Who can do it                                                     |
|:-------------------------|:------------------------------------------------------------------|
| Protect a branch         | At least the Maintainer role.                                     |
| Push to the branch       | GitLab administrators and anyone with **Allowed** permission. (1) |
| Force push to the branch | No one.                                                           |
| Delete the branch        | No one.                                                           |

1. Users with the Developer role can create a project in a group, but might not be allowed to
   initially push to the [default branch](repository/branches/default.md).

### Set the default branch protection level

Administrators can set a default branch protection level in the
[Admin Area](../project/repository/branches/default.md#instance-level-default-branch-protection).

## Configure a protected branch

Prerequisite:

- You must have at least the Maintainer role.

To protect a branch:

1. Go to your project and select **Settings > Repository**.
1. Expand **Protected branches**.
1. From the **Branch** dropdown list, select the branch you want to protect.
1. From the **Allowed to merge** list, select a role, or group that can merge into this branch. In GitLab Premium, you can also add users.
1. From the **Allowed to push** list, select a role, group, or user that can push to this branch. In GitLab Premium, you can also add users.
1. Select **Protect**.

The protected branch displays in the list of protected branches.

## Configure multiple protected branches by using a wildcard

Prerequisite:

- You must have at least the Maintainer role.

To protect multiple branches at the same time:

1. Go to your project and select **Settings > Repository**.
1. Expand **Protected branches**.
1. From the **Branch** dropdown list, type the branch name and a wildcard.
   For example:

   | Wildcard protected branch | Matching branches                                      |
   |---------------------------|--------------------------------------------------------|
   | `*-stable`                | `production-stable`, `staging-stable`                  |
   | `production/*`            | `production/app-server`, `production/load-balancer`    |
   | `*gitlab*`                | `gitlab`, `gitlab/staging`, `master/gitlab/production` |

1. From the **Allowed to merge** list, select a role, or group that can merge into this branch. In GitLab Premium, you can also add users.
1. From the **Allowed to push** list, select a role, group, or user that can push to this branch. In GitLab Premium, you can also add users.
1. Select **Protect**.

The protected branch displays in the list of protected branches.

## Create a protected branch

Users with at least the Developer role can create a protected branch.

Prerequisites:

- **Allowed to push** is set to **No one**
- **Allowed to merge** is set to **Developers**.

You can create a protected branch by using the UI or API only.
This prevents you from accidentally creating a branch
from the command line or from a Git client application.

To create a new branch through the user interface:

1. Go to **Repository > Branches**.
1. Select **New branch**.
1. Fill in the branch name and select an existing branch, tag, or commit to
   base the new branch on. Only existing protected branches and commits
   that are already in protected branches are accepted.

## Require everyone to submit merge requests for a protected branch

You can force everyone to submit a merge request, rather than allowing them to check in directly
to a protected branch. This is compatible with workflows like the [GitLab workflow](../../topics/gitlab_flow.md).

1. Go to your project and select **Settings > Repository**.
1. Expand **Protected branches**.
1. From the **Branch** dropdown list, select the branch you want to protect.
1. From the **Allowed to merge** list, select **Developers + Maintainers**.
1. From the **Allowed to push** list, select **No one**.
1. Select **Protect**.

## Allow everyone to push directly to a protected branch

You can allow everyone with write access to push to the protected branch.

1. Go to your project and select **Settings > Repository**.
1. Expand **Protected branches**.
1. From the **Branch** dropdown list, select the branch you want to protect.
1. From the **Allowed to push** list, select **Developers + Maintainers**.
1. Select **Protect**.

## Allow deploy keys to push to a protected branch

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/30769) in GitLab 13.7.
> - This feature was selectively deployed in GitLab.com 13.7, and may not be available for all users.
> - This feature is available for all users in GitLab 13.9.

You can permit the owner of a [deploy key](deploy_keys/index.md) to push to a protected branch.
The deploy key works, even if the user isn't a member of the related project. However, the owner of the deploy
key must have at least read access to the project.

Prerequisites:

- The deploy key must be enabled for your project. A project deploy key is enabled by default when
  it is created. However, a public deploy key must be
  [granted](deploy_keys/index.md#grant-project-access-to-a-public-deploy-key) access to the
  project.
- The deploy key must have [write access](deploy_keys/index.md#permissions) to your project
  repository.

To allow a deploy key to push to a protected branch:

1. Go to your project and select **Settings > Repository**.
1. Expand **Protected branches**.
1. From the **Branch** dropdown list, select the branch you want to protect.
1. From the **Allowed to push** list, select the deploy key.
1. Select **Protect**.

Deploy keys are not available in the **Allowed to merge** dropdown list.

## Allow force push on a protected branch

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/15611) in GitLab 13.10 [with a flag](../../administration/feature_flags.md) named `allow_force_push_to_protected_branches`. Disabled by default.
> - [Enabled on GitLab.com and self-managed](https://gitlab.com/gitlab-org/gitlab/-/issues/323431) in GitLab 14.0. Feature flag `allow_force_push_to_protected_branches` removed.

You can allow [force pushes](../../topics/git/git_rebase.md#force-push) to
protected branches.

To protect a new branch and enable force push:

1. Go to your project and select **Settings > Repository**.
1. Expand **Protected branches**.
1. From the **Branch** dropdown list, select the branch you want to protect.
1. From the **Allowed to push** and **Allowed to merge** lists, select the settings you want.
1. To allow all users with push access to force push, turn on the **Allowed to force push** toggle.
1. To reject code pushes that change files listed in the `CODEOWNERS` file, turn on the
   **Require approval from code owners** toggle.
1. Select **Protect**.

To enable force pushes on branches that are already protected:

1. Go to your project and select **Settings > Repository**.
1. Expand **Protected branches**.
1. In the list of protected branches, next to the branch, turn on the **Allowed to force push** toggle.

Members who can push to this branch can now also force push.

## Require Code Owner approval on a protected branch **(PREMIUM)**

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/13251) in GitLab 12.4.
> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/35097) in GitLab 13.5, users and groups who can push to protected branches do not have to use a merge request to merge their feature branches. This means they can skip merge request approval rules.

For a protected branch, you can require at least one approval by a [Code Owner](code_owners.md).

To protect a new branch and enable Code Owner's approval:

1. Go to your project and select **Settings > Repository**.
1. Expand **Protected branches**.
1. From the **Branch** dropdown list, select the branch you want to protect.
1. From the **Allowed to push** and **Allowed to merge** lists, select the settings you want.
1. Turn on the **Require approval from code owners** toggle.
1. Select **Protect**.

To enable Code Owner's approval on branches that are already protected:

1. Go to your project and select **Settings > Repository**.
1. Expand **Protected branches**.
1. In the list of protected branches, next to the branch, turn on the **Code owner approval** toggle.

When enabled, all merge requests for these branches require approval
by a Code Owner per matched rule before they can be merged.
Additionally, direct pushes to the protected branch are denied if a rule is matched.

Any user who is not specified in the `CODEOWNERS` file cannot push
changes for the specified files or paths, unless they are specifically allowed to.
You don't have to restrict developers from pushing directly to the
protected branch. Instead, you can restrict pushing to certain files where a review by
Code Owners is required.

In [GitLab Premium 13.5 and later](https://gitlab.com/gitlab-org/gitlab/-/issues/35097), users and groups
who are allowed to push to protected branches do not need a merge request to merge their feature branches.
Thus, they can skip merge request approval rules, Code Owners included.

## Run pipelines on protected branches

The permission to merge or push to protected branches defines
whether or not a user can run CI/CD pipelines and execute actions on jobs.

See [Security on protected branches](../../ci/pipelines/index.md#pipeline-security-on-protected-branches)
for details about the pipelines security model.

## Delete a protected branch

Users with at least the Maintainer role can manually delete protected
branches by using the GitLab web interface:

1. Go to **Repository > Branches**.
1. Next to the branch you want to delete, select **Delete** (**{remove}**).
1. On the confirmation dialog, type the branch name and select **Delete protected branch**.

Protected branches can only be deleted by using GitLab either from the UI or API.
This prevents accidentally deleting a branch through local Git commands or
third-party Git clients.

<!-- ## Troubleshooting

Include any troubleshooting steps that you can foresee. If you know beforehand what issues
one might have when setting this up, or when something is changed, or on upgrading, it's
important to describe those, too. Think of things that may go wrong and include them here.
This is important to minimize requests for support, and to avoid doc comments with
questions that you know someone might ask.

Each scenario can be a third-level heading, e.g. `### Getting error message X`.
If you have none to add when creating a doc, leave this section in place
but commented out to help encourage others to add to it in the future. -->
