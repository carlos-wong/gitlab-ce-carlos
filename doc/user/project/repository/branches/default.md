---
stage: Create
group: Source Code
info: "To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments"
type: concepts, howto
---

# Default branch **(FREE)**

When you create a new [project](../../index.md), GitLab creates a default branch
in the repository. A default branch has special configuration options not shared
by other branches:

- It cannot be deleted.
- It's [initially protected](../../protected_branches.md#protected-branches) against
  forced pushes.
- When a merge request uses an
  [issue closing pattern](../../issues/managing_issues.md#closing-issues-automatically)
  to close an issue, the work is merged into this branch.

The name of your [new project's](../../index.md) default branch depends on any
instance-level or group-level configuration changes made by your GitLab administrator.
GitLab checks first for specific customizations, then checks at a broader level,
using the GitLab default only if no customizations are set:

1. A [project-specific](#change-the-default-branch-name-for-a-project) custom default branch name.
1. A [subgroup-level](#group-level-custom-initial-branch-name) custom default branch name.
1. A [group-level](#group-level-custom-initial-branch-name) custom default branch name.
1. An [instance-level](#instance-level-custom-initial-branch-name) custom default branch name.
1. If no custom default branch name is set at any level, GitLab defaults to:
   - `main`: Projects created with GitLab 14.0 or later.
   - `master`: Projects created before GitLab 14.0.

In the GitLab UI, you can change the defaults at any level. GitLab also provides
the [Git commands you need](#update-the-default-branch-name-in-your-repository) to update your copy of the repository.

## Change the default branch name for a project

To update the default branch name for an individual [project](../../index.md):

1. Sign in to GitLab with at least the Maintainer role.
1. In the left navigation menu, go to **Settings > Repository**.
1. Expand **Default branch**, and select a new default branch.
1. Optional. Select the **Auto-close referenced issues on default branch** checkbox to close
   issues when a merge request
   [uses a closing pattern](../../issues/managing_issues.md#closing-issues-automatically).
1. Select **Save changes**.

API users can also use the `default_branch` attribute of the
[Projects API](../../../../api/projects.md) when creating or editing a project.

## Change the default branch name for an instance or group

GitLab administrators can configure a new default branch name at the
[instance level](#instance-level-custom-initial-branch-name) or
[group level](#group-level-custom-initial-branch-name).

### Instance-level custom initial branch name **(FREE SELF)**

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/221013) in GitLab 13.2 [with a flag](../../../../administration/feature_flags.md) named `global_default_branch_name`. Enabled by default.
> - [Generally available](https://gitlab.com/gitlab-org/gitlab/-/issues/325163) in GitLab 13.12. Feature flag `global_default_branch_name` removed.

GitLab [administrators](../../../permissions.md) of self-managed instances can
customize the initial branch for projects hosted on that instance. Individual
groups and subgroups can override this instance-wide setting for their projects.

1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > Repository**.
1. Expand **Default initial branch name**.
1. Change the default initial branch to a custom name of your choice.
1. Select **Save changes**.

Projects created on this instance after you change the setting use the
custom branch name, unless a group-level or subgroup-level configuration
overrides it.

### Group-level custom initial branch name

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/221014) in GitLab 13.6.

Users with at least the Owner role of groups and subgroups can configure the default branch name for a group:

1. Go to the group **Settings > Repository**.
1. Expand **Default branch**.
1. Change the default initial branch to a custom name of your choice.
1. Select **Save changes**.

Projects created in this group after you change the setting use the custom branch name,
unless a subgroup configuration overrides it.

## Protect initial default branches **(FREE SELF)**

GitLab administrators and group owners can define [branch protections](../../../project/protected_branches.md)
to apply to every repository's [default branch](#default-branch)
at the [instance level](#instance-level-default-branch-protection) and
[group level](#group-level-default-branch-protection) with one of the following options:

- **Not protected** - Both developers and maintainers can push new commits
   and force push.
- **Protected against pushes** - Developers cannot push new commits, but are
   allowed to accept merge requests to the branch. Maintainers can push to the branch.
- **Partially protected** - Both developers and maintainers can push new commits,
   but cannot force push.
- **Fully protected** - Developers cannot push new commits, but maintainers can.
   No one can force push.

### Instance-level default branch protection **(FREE SELF)**

This setting applies only to each repository's default branch. To protect other branches,
you must either:

- Configure [branch protection in the repository](../../../project/protected_branches.md).
- Configure [branch protection for groups](../../../group/index.md#change-the-default-branch-protection-of-a-group).

Administrators of self-managed instances can customize the initial default branch protection for projects hosted on that instance. Individual
groups and subgroups can override this instance-wide setting for their projects.

1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > Repository**.
1. Expand **Default branch**.
1. Select [**Initial default branch protection**](#protect-initial-default-branches).
1. To allow group owners to override the instance's default branch protection, select
   [**Allow owners to manage default branch protection per group**](#prevent-overrides-of-default-branch-protection).
1. Select **Save changes**.

#### Prevent overrides of default branch protection **(PREMIUM SELF)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/211944) in GitLab 13.0.

Instance-level protections for default branches
can be overridden on a per-group basis by the group's owner. In
[GitLab Premium or higher](https://about.gitlab.com/pricing/), GitLab administrators can
disable this privilege for group owners, enforcing the instance-level protection rule:

1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > Repository**.
1. Expand the **Default branch** section.
1. Clear the **Allow owners to manage default branch protection per group** checkbox.
1. Select **Save changes**.

NOTE:
GitLab administrators can still update the default branch protection of a group.

### Group-level default branch protection **(PREMIUM)**

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/7583) in GitLab 12.9.
> - [Settings moved and renamed](https://gitlab.com/gitlab-org/gitlab/-/issues/340403) in GitLab 14.9.

Instance-level protections for [default branch](#default-branch)
can be overridden on a per-group basis by the group's owner. In
[GitLab Premium or higher](https://about.gitlab.com/pricing/), GitLab administrators can
[enforce protection of initial default branches](#prevent-overrides-of-default-branch-protection)
which locks this setting for group owners.

1. On the top bar, select **Menu > Groups** and find your group.
1. On the left sidebar, select **Settings > Repository**.
1. Expand **Default branch**.
1. Select [**Initial default branch protection**](#protect-initial-default-branches).
1. Select **Save changes**.

## Update the default branch name in your repository

WARNING:
Changing the name of your default branch can potentially break tests,
CI/CD configuration, services, helper utilities, and any integrations your repository
uses. Before you change this branch name, consult with your project owners and maintainers.
Ensure they understand the scope of this change includes references to the old
branch name in related code and scripts.

When changing the default branch name for an existing repository, you should preserve
the history of your default branch by renaming it, instead of creating a new branch. This example
renames a Git repository's (`example`) default branch.

1. On your local command line, navigate to your `example` repository, and ensure
   you're on the default branch:

   ```plaintext
   cd example
   git checkout master
   ```

1. Rename the existing default branch to the new name (`main`). The argument `-m`
   transfers all commit history to the new branch:

   ```plaintext
   git branch -m master main
   ```

1. Push the newly created `main` branch upstream, and set your local branch to track
   the remote branch with the same name:

   ```plaintext
   git push -u origin main
   ```

1. If you plan to remove the old default branch, update `HEAD` to point to your new default branch, `main`:

   ```plaintext
   git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
   ```

1. Sign in to GitLab with at least the Maintainer
   role and follow the instructions to
   [change the default branch for this project](#change-the-default-branch-name-for-a-project).
   Select `main` as your new default branch.
1. Protect your new `main` branch as described in the [protected branches documentation](../../protected_branches.md).
1. Optional. If you want to delete the old default branch:
   1. Verify that nothing is pointing to it.
   1. Delete the branch on the remote:

      ```plaintext
      git push origin --delete master
      ```

      You can delete the branch at a later time, after you confirm the new default branch is working as expected.

1. Notify your project contributors of this change, because they must also take some steps:

   - Contributors should pull the new default branch to their local copy of the repository.
   - Contributors with open merge requests that target the old default branch should manually
     re-point the merge requests to use `main` instead.
1. In your repository, update any references to the old branch name in your code.
1. Update references to the old branch name in related code and scripts that reside outside
   your repository, such as helper utilities and integrations.

## Default branch rename redirect

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/329100) in GitLab 14.1

URLs for specific files or directories in a project embed the project's default
branch name, and are often found in documentation or browser bookmarks. When you
[update the default branch name in your repository](#update-the-default-branch-name-in-your-repository),
these URLs change, and must be updated.

To ease the transition period, whenever the default branch for a project is
changed, GitLab records the name of the old default branch. If that branch is
deleted, attempts to view a file or directory on it are redirected to the
current default branch, instead of displaying the "not found" page.

## Related topics

- [Configure a default branch for your wiki](../../wiki/index.md)
- [Discussion of default branch renaming](https://lore.kernel.org/git/pull.656.v4.git.1593009996.gitgitgadget@gmail.com/)
  on the Git mailing list
- [March 2021 blog post: The new Git default branch name](https://about.gitlab.com/blog/2021/03/10/new-git-default-branch-name/)

## Troubleshooting

### Unable to change default branch: resets to current branch

We are tracking this problem in [issue 20474](https://gitlab.com/gitlab-org/gitlab/-/issues/20474).
This issue often occurs when a branch named `HEAD` is present in the repository.
To fix the problem:

1. In your local repository, create a new temporary branch and push it:

   ```shell
   git checkout -b tmp_default && git push -u origin tmp_default
   ```

1. In GitLab, proceed to [change the default branch](#change-the-default-branch-name-for-a-project) to that temporary branch.
1. From your local repository, delete the `HEAD` branch:

   ```shell
   git push -d origin HEAD
   ```

1. In GitLab, [change the default branch](#change-the-default-branch-name-for-a-project) to the one you intend to use.

### Query GraphQL for default branches

You can use a [GraphQL query](../../../../api/graphql/index.md)
to retrieve the default branches for all projects in a group.

To return all projects in a single page of results, replace `GROUPNAME` with the
full path to your group. GitLab returns the first page of results. If `hasNextPage`
is `true`, you can request the next page by replacing the `null` in `after: null`
with the value of `endCursor`:

```graphql
{
 group(fullPath: "GROUPNAME") {
   projects(after: null) {
     pageInfo {
       hasNextPage
       endCursor
     }
     nodes {
       name
       repository {
         rootRef
       }
     }
   }
 }
}
```
