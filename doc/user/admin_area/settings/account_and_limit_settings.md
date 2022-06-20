---
stage: Create
group: Source Code
info: "To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments"
type: reference
---

# Account and limit settings **(FREE SELF)**

## Default projects limit

You can configure the default maximum number of projects new users can create in their
personal namespace. This limit affects only new user accounts created after you change
the setting. This setting is not retroactive for existing users, but you can separately edit
the [project limits for existing users](#projects-limit-for-a-user).

To configure the maximum number of projects in personal namespaces for new users:

1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > General**, then expand **Account and limit**.
1. Increase or decrease that **Default projects limit** value.

If you set **Default projects limit** to 0, users are not allowed to create projects
in their users personal namespace. However, projects can still be created in a group.

### Projects limit for a user

You can edit a specific user, and change the maximum number of projects this user
can create in their personal namespace:

1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Overview** > **Users**.
1. From the list of users, select a user.
1. Select **Edit**.
1. Increase or decrease the **Projects limit** value.

## Max attachment size

The maximum file size for attachments in GitLab comments and replies is 10 MB.
To change the maximum attachment size:

1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > General**, then expand **Account and limit**.
1. Increase or decrease by changing the value in **Maximum attachment size (MB)**.

If you choose a size larger than the configured value for the web server,
you may receive errors. Read the [troubleshooting section](#troubleshooting) for more
details.

For GitLab.com repository size limits, read [accounts and limit settings](../../gitlab_com/index.md#account-and-limit-settings).

## Max push size

You can change the maximum push size for your repository:

1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > General**, then expand **Account and limit**.
1. Increase or decrease by changing the value in **Maximum push size (MB)**.

NOTE:
When you [add files to a repository](../../project/repository/web_editor.md#create-a-file)
through the web UI, the maximum **attachment** size is the limiting factor,
because the [web server](../../../development/architecture.md#components)
must receive the file before GitLab can generate the commit.
Use [Git LFS](../../../topics/git/lfs/index.md) to add large files to a repository.

## Max import size

> [Modified](https://gitlab.com/gitlab-org/gitlab/-/issues/251106) from 50 MB to unlimited in GitLab 13.8.

To modify the maximum file size for imports in GitLab:

1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > General**, then expand **Account and limit**.
1. Increase or decrease by changing the value in **Maximum import size (MB)**.

If you choose a size larger than the configured value for the web server,
you may receive errors. See the [troubleshooting section](#troubleshooting) for more
details.

For GitLab.com repository size limits, read [accounts and limit settings](../../gitlab_com/index.md#account-and-limit-settings).

## Personal access token prefix

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/20968) in GitLab 13.7.
> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/342327) in GitLab 14.5, a default prefix.

You can specify a prefix for personal access tokens. You might use a prefix
to find tokens more quickly, or for use with automation tools.

The default prefix is `glpat-` but administrators can change it.

[Project access tokens](../../project/settings/project_access_tokens.md) also inherit this prefix.

### Set a prefix

To change the default global prefix:

1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > General**.
1. Expand the **Account and limit** section.
1. Fill in the **Personal Access Token prefix** field.
1. Click **Save changes**.

You can also configure the prefix by using the
[settings API](../../../api/settings.md).

## Repository size limit **(PREMIUM SELF)**

Repositories in your GitLab instance can grow quickly, especially if you are
using LFS. Their size can grow exponentially, rapidly consuming available storage.
To prevent this from happening, you can set a hard limit for your repositories' size.
This limit can be set globally, per group, or per project, with per project limits
taking the highest priority.

There are numerous use cases where you might set up a limit for repository size.
For instance, consider the following workflow:

1. Your team develops apps which require large files to be stored in
   the application repository.
1. Although you have enabled [Git LFS](../../../topics/git/lfs/index.md#git-large-file-storage-lfs)
   to your project, your storage has grown significantly.
1. Before you exceed available storage, you set up a limit of 10 GB
   per repository.

NOTE:
For GitLab.com repository size limits, read [accounts and limit settings](../../gitlab_com/index.md#account-and-limit-settings).

### How it works

Only a GitLab administrator can set those limits. Setting the limit to `0` means
there are no restrictions.

These settings can be found in:

- Each project's settings:
  1. From the Project's homepage, navigate to **Settings > General**.
  1. Fill in the **Repository size limit (MB)** field in the **Naming, topics, avatar** section.
  1. Click **Save changes**.
- Each group's settings:
  1. From the Group's homepage, navigate to **Settings > General**.
  1. Fill in the **Repository size limit (MB)** field in the **Naming, visibility** section.
  1. Click **Save changes**.
- GitLab global settings:
  1. On the top bar, select **Menu > Admin**.
  1. On the left sidebar, select **Settings > General**.
  1. Expand the **Account and limit** section.
  1. Fill in the **Size limit per repository (MB)** field.
  1. Click **Save changes**.

The first push of a new project, including LFS objects, is checked for size.
If the sum of their sizes exceeds the maximum allowed repository size, the push
is rejected.

NOTE:
The repository size limit includes repository files and LFS, but does not include artifacts, uploads,
wiki, packages, or snippets. The repository size limit applies to both private and public projects.

For details on manually purging files, see [reducing the repository size using Git](../../project/repository/reducing_the_repo_size_using_git.md).

## Troubleshooting

### 413 Request Entity Too Large

When attaching a file to a comment or reply in GitLab displays a `413 Request Entity Too Large`
error, the [max attachment size](#max-attachment-size)
is probably larger than the web server's allowed value.

To increase the max attachment size to 200 MB in a
[Omnibus GitLab](https://docs.gitlab.com/omnibus/) install, you may need to
add the line below to `/etc/gitlab/gitlab.rb` before increasing the max attachment size:

```ruby
nginx['client_max_body_size'] = "200m"
```

## Customize session duration for Git Operations when 2FA is enabled **(PREMIUM SELF)**

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/296669) in GitLab 13.9.
> - It's deployed behind a feature flag, disabled by default.

FLAG:
On self-managed GitLab, by default this feature is not available. To make it available, ask an administrator to [enable the feature flag](../../../administration/feature_flags.md) named `two_factor_for_cli`. On GitLab.com, this feature is not available. This feature is not ready for production use. This feature flag also affects [2FA for Git over SSH operations](../../../security/two_factor_authentication.md#2fa-for-git-over-ssh-operations).

GitLab administrators can choose to customize the session duration (in minutes) for Git operations when 2FA is enabled. The default is 15 and this can be set to a value between 1 and 10080.

To set a limit on how long these sessions are valid:

1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > General**.
1. Expand the **Account and limit** section.
1. Fill in the **Session duration for Git operations when 2FA is enabled (minutes)** field.
1. Click **Save changes**.

## Limit the lifetime of SSH keys **(ULTIMATE SELF)**

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/1007) in GitLab 14.6 [with a flag](../../../administration/feature_flags.md) named `ff_limit_ssh_key_lifetime`. Disabled by default.
> - [Enabled on self-managed](https://gitlab.com/gitlab-org/gitlab/-/issues/346753) in GitLab 14.6.
> - [Generally available](https://gitlab.com/gitlab-org/gitlab/-/issues/1007) in GitLab 14.7. [Feature flag ff_limit_ssh_key_lifetime](https://gitlab.com/gitlab-org/gitlab/-/issues/347408) removed.

Users can optionally specify a lifetime for
[SSH keys](../../ssh.md).
This lifetime is not a requirement, and can be set to any arbitrary number of days.

SSH keys are user credentials to access GitLab.
However, organizations with security requirements may want to enforce more protection by
requiring the regular rotation of these keys.

### Set a lifetime

Only a GitLab administrator can set a lifetime. Leaving it empty means
there are no restrictions.

To set a lifetime on how long SSH keys are valid:

1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > General**.
1. Expand the **Account and limit** section.
1. Fill in the **Maximum allowable lifetime for SSH keys (days)** field.
1. Click **Save changes**.

Once a lifetime for SSH keys is set, GitLab:

- Requires users to set an expiration date that is no later than the allowed lifetime on new
  SSH keys.
- Applies the lifetime restriction to existing SSH keys. Keys with no expiry or a lifetime
  greater than the maximum immediately become invalid.

NOTE:
When a user's SSH key becomes invalid they can delete and re-add the same key again.

## Allow expired SSH keys to be used (DEPRECATED) **(ULTIMATE SELF)**

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/250480) in GitLab 13.9.
> - [Enabled by default](https://gitlab.com/gitlab-org/gitlab/-/issues/320970) in GitLab 14.0.
> - [Deprecated](https://gitlab.com/gitlab-org/gitlab/-/issues/351963) in GitLab 14.8.

WARNING:
This feature was [deprecated](https://gitlab.com/gitlab-org/gitlab/-/issues/351963) in GitLab 14.8.

By default, expired SSH keys **are not usable**.

To allow the use of expired SSH keys:

1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > General**.
1. Expand the **Account and limit** section.
1. Uncheck the **Enforce SSH key expiration** checkbox.

Disabling SSH key expiration immediately enables all expired SSH keys.

## Limit the lifetime of personal access tokens **(ULTIMATE SELF)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/3649) in GitLab 12.6.

Users can optionally specify a lifetime for
[personal access tokens](../../profile/personal_access_tokens.md).
This lifetime is not a requirement, and can be set to any arbitrary number of days.

Personal access tokens are the only tokens needed for programmatic access to GitLab.
However, organizations with security requirements may want to enforce more protection by
requiring the regular rotation of these tokens.

### Set a lifetime

Only a GitLab administrator can set a lifetime. Leaving it empty means
there are no restrictions.

To set a lifetime on how long personal access tokens are valid:

1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > General**.
1. Expand the **Account and limit** section.
1. Fill in the **Maximum allowable lifetime for personal access tokens (days)** field.
1. Click **Save changes**.

Once a lifetime for personal access tokens is set, GitLab:

- Applies the lifetime for new personal access tokens, and require users to set an expiration date
  and a date no later than the allowed lifetime.
- After three hours, revoke old tokens with no expiration date or with a lifetime longer than the
  allowed lifetime. Three hours is given to allow administrators to change the allowed lifetime,
  or remove it, before revocation takes place.

## Allow expired Personal Access Tokens to be used (DEPRECATED) **(ULTIMATE SELF)**

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/214723) in GitLab 13.1.
> - [Feature flag removed](https://gitlab.com/gitlab-org/gitlab/-/issues/296881) in GitLab 13.9.
> - [Deprecated](https://gitlab.com/gitlab-org/gitlab/-/issues/351962) in GitLab 14.8.

WARNING:
This feature was [deprecated](https://gitlab.com/gitlab-org/gitlab/-/issues/351962) in GitLab 14.8.

By default, expired personal access tokens (PATs) **are not usable**.

To allow the use of expired PATs:

1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > General**.
1. Expand the **Account and limit** section.
1. Uncheck the **Enforce personal access token expiration** checkbox.

## Disable user profile name changes **(PREMIUM SELF)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/24605) in GitLab 12.7.

To maintain integrity of user details in [Audit Events](../../../administration/audit_events.md), GitLab administrators can choose to disable a user's ability to change their profile name.

To do this:

1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > General**, then expand **Account and limit**.
1. Select the **Prevent users from changing their profile name** checkbox.

NOTE:
When this ability is disabled, GitLab administrators can still use the
[Admin UI](../index.md#administering-users) or the
[API](../../../api/users.md#user-modification) to update usernames.
