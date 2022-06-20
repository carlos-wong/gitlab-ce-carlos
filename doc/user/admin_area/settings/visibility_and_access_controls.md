---
stage: Create
group: Source Code
info: "To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments"
type: reference
---

# Control access and visibility **(FREE SELF)**

GitLab enables users with administrator access to enforce
specific controls on branches, projects, snippets, groups, and more.

To access the visibility and access control options:

1. Sign in to GitLab as a user with Administrator access level.
1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > General**.
1. Expand the **Visibility and access controls** section.

## Define which roles can create projects

Instance-level protections for project creation define which roles can
[add projects to a group](../../group/index.md#specify-who-can-add-projects-to-a-group)
on the instance. To alter which roles have permission to create projects:

1. Sign in to GitLab as a user with Administrator access level.
1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > General**.
1. Expand the **Visibility and access controls** section.
1. For **Default project creation protection**, select the desired roles:
   - No one.
   - Maintainers.
   - Developers and Maintainers.
1. Select **Save changes**.

## Restrict project deletion to Administrators **(PREMIUM SELF)**

Anyone with the **Owner** role, either at the project or group level, can
delete a project. To allow only users with administrator access to delete projects:

1. Sign in to GitLab as a user with Administrator access level.
1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > General**.
1. Expand the **Visibility and access controls** section.
1. Scroll to **Default project deletion protection**, and select **Only admins can delete project**.
1. Select **Save changes**.

## Default delayed project deletion **(PREMIUM SELF)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/255449) in GitLab 14.2 for groups created after August 12, 2021.

[Delayed project deletion](../../project/settings/index.md#delayed-project-deletion) allows projects in a group (not a personal namespace)
to be deleted after a period of delay.

To enable delayed project deletion by default in new groups:

1. Check the **Default delayed project deletion** checkbox.
1. Select **Save changes**.

## Default deletion delay **(PREMIUM SELF)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/32935) in GitLab 12.6.

By default, a project marked for deletion is permanently removed with immediate effect.
See [delayed project deletion](../../project/settings/index.md#delayed-project-deletion) to learn more.
By default, a group marked for deletion is permanently removed after seven days.

WARNING:
The default behavior of [Delayed Project deletion](https://gitlab.com/gitlab-org/gitlab/-/issues/32935) in GitLab 12.6 was changed to
[Immediate deletion](https://gitlab.com/gitlab-org/gitlab/-/issues/220382) in GitLab 13.2.

The default period is seven days, and can be changed. Setting this period to `0` enables immediate removal
of projects or groups.

To change this period:

1. Select the desired option.
1. Click **Save changes**.

### Override defaults and delete immediately

Alternatively, projects that are marked for removal can be deleted immediately. To do so:

1. [Restore the project](../../project/settings/#restore-a-project).
1. Delete the project as described in the
   [Administering Projects page](../../admin_area/#administering-projects).

## Configure project visibility defaults

To set the default [visibility levels for new projects](../../public_access.md):

1. Sign in to GitLab as a user with Administrator access level.
1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > General**.
1. Expand the **Visibility and access controls** section.
1. Select the desired default project visibility:
   - **Private** - Project access must be granted explicitly to each user. If this
     project is part of a group, access will be granted to members of the group.
   - **Internal** - The project can be accessed by any logged in user except external users.
   - **Public** - The project can be accessed without any authentication.
1. Select **Save changes**.

## Configure snippet visibility defaults

To set the default visibility levels for new [snippets](../../snippets.md):

1. Sign in to GitLab as a user with Administrator access level.
1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > General**.
1. Expand the **Visibility and access controls** section.
1. Select the desired default snippet visibility.
1. Select **Save changes**.

For more details on snippet visibility, read
[Project visibility](../../public_access.md).

## Configure group visibility defaults

To set the default visibility levels for new groups:

1. Sign in to GitLab as a user with Administrator access level.
1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > General**.
1. Expand the **Visibility and access controls** section.
1. Select the desired default group visibility:
   - **Private** - The group and its projects can only be viewed by members.
   - **Internal** - The group and any internal projects can be viewed by any logged in user except external users.
   - **Public** - The group and any public projects can be viewed without any authentication.
1. Select **Save changes**.

For more details on group visibility, see
[Group visibility](../../group/index.md#group-visibility).

## Restrict visibility levels

To restrict visibility levels for projects, snippets, and selected pages:

1. Sign in to GitLab as a user with Administrator access level.
1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > General**.
1. Expand the **Visibility and access controls** section.
1. In the **Restricted visibility levels** section, select the desired visibility levels to restrict.
   If you restrict the **Public** level:
   - User profiles are only visible to logged in users via the Web interface.
   - User attributes are only visible to authenticated users via the GraphQL API.
1. Select **Save changes**.

For more details on project visibility, see
[Project visibility](../../public_access.md).

## Configure allowed import sources

You can specify from which hosting sites users can [import their projects](../../project/import/index.md):

1. Sign in to GitLab as a user with Administrator access level.
1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > General**.
1. Expand the **Visibility and access controls** section.
1. Select each of **Import sources** to allow.
1. Select **Save changes**.

## Enable project export

To enable the export of
[projects and their data](../../project/settings/import_export.md#export-a-project-and-its-data):

1. Sign in to GitLab as a user with Administrator access level.
1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > General**.
1. Expand the **Visibility and access controls** section.
1. Select **Project export enabled**.
1. Select **Save changes**.

## Configure enabled Git access protocols

With GitLab access restrictions, you can select the protocols users can use to
communicate with GitLab. Disabling an access protocol does not block port access to the
server itself. The ports used for the protocol, SSH or HTTP(S), are still accessible.
The GitLab restrictions apply at the application level.

To specify the enabled Git access protocols:

1. Sign in to GitLab as a user with Administrator access level.
1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > General**.
1. Expand the **Visibility and access controls** section.
1. Select the desired Git access protocols:
   - Both SSH and HTTP(S)
   - Only SSH
   - Only HTTP(S)
1. Select **Save changes**.

When both SSH and HTTP(S) are enabled, users can choose either protocol.
If only one protocol is enabled:

- The project page shows only the allowed protocol's URL, with no option to
  change it.
- GitLab shows a tooltip when you hover over the URL's protocol, if user action
  (such as adding a SSH key or setting a password) is required:

  ![Project URL with SSH only access](img/restricted_url.png)

GitLab only allows Git actions for the protocols you select.

WARNING:
GitLab versions [10.7 and later](https://gitlab.com/gitlab-org/gitlab-foss/-/merge_requests/18021),
allow the HTTP(S) protocol for Git clone or fetch requests done by GitLab Runner
from CI/CD jobs, even if you select **Only SSH**.

## Customize Git clone URL for HTTP(S)

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/18422) in GitLab 12.4.

You can customize project Git clone URLs for HTTP(S), which affects the clone
panel:

For example, if:

- Your GitLab instance is at `https://example.com`, then project clone URLs are like
  `https://example.com/foo/bar.git`.
- You want clone URLs that look like `https://git.example.com/gitlab/foo/bar.git` instead,
  you can set this setting to `https://git.example.com/gitlab/`.

![Custom Git clone URL for HTTP](img/custom_git_clone_url_for_https_v12_4.png)

To specify a custom Git clone URL for HTTP(S):

1. Enter a root URL for **Custom Git clone URL for HTTP(S)**.
1. Click on **Save changes**.

NOTE:
SSH clone URLs can be customized in `gitlab.rb` by setting `gitlab_rails['gitlab_ssh_host']` and
other related settings.

## Configure defaults for RSA, DSA, ECDSA, ED25519, ECDSA_SK, ED25519_SK SSH keys

These options specify the permitted types and lengths for SSH keys.

To specify a restriction for each key type:

1. Select the desired option from the dropdown.
1. Click **Save changes**.

For more details, see [SSH key restrictions](../../../security/ssh_keys_restrictions.md).

## Enable project mirroring

This option is enabled by default. By disabling it, both
[pull mirroring](../../project/repository/mirror/pull.md) and [push mirroring](../../project/repository/mirror/push.md) no longer
work in every repository. They can only be re-enabled by an administrator user on a per-project basis.

![Mirror settings](img/mirror_settings.png)

<!-- ## Troubleshooting

Include any troubleshooting steps that you can foresee. If you know beforehand what issues
one might have when setting this up, or when something is changed, or on upgrading, it's
important to describe those, too. Think of things that may go wrong and include them here.
This is important to minimize requests for support, and to avoid doc comments with
questions that you know someone might ask.

Each scenario can be a third-level heading, e.g. `### Getting error message X`.
If you have none to add when creating a doc, leave this section in place
but commented out to help encourage others to add to it in the future. -->
