---
stage: Manage
group: Workspace
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
type: reference
---

# Project and group visibility **(FREE)**

GitLab allows users with the Owner role to set a project's or group's visibility as:

- **Public**
- **Internal**
- **Private**

These visibility levels affect who can see the project in the public access directory (`/public`
for your GitLab instance). For example, <https://gitlab.com/public>.
You can control the visibility of individual features with
[project feature settings](permissions.md#project-features).

## Public projects and groups

Public projects can be cloned **without any** authentication over HTTPS.

They are listed in the public access directory (`/public`) for all users.

**Any signed-in user** has the Guest role on the repository.

NOTE:
By default, `/public` is visible to unauthenticated users. However, if the
[**Public** visibility level](admin_area/settings/visibility_and_access_controls.md#restrict-visibility-levels)
is restricted, `/public` is visible only to signed-in users.

## Internal projects and groups

Internal projects can be cloned by any signed-in user except
[external users](permissions.md#external-users).

They are also listed in the public access directory (`/public`), but only for signed-in users.

Any signed-in users except [external users](permissions.md#external-users) have the
Guest role on the repository.

NOTE:
From July 2019, the `Internal` visibility setting is disabled for new projects, groups,
and snippets on GitLab.com. Existing projects, groups, and snippets using the `Internal`
visibility setting keep this setting. You can read more about the change in the
[relevant issue](https://gitlab.com/gitlab-org/gitlab/-/issues/12388).

## Private projects and groups

Private projects can only be cloned and viewed by project members (except for guests).

They appear in the public access directory (`/public`) for project members only.

## Change project visibility

Prerequisite:

- You must have the Owner role for a project.

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Settings > General**.
1. Expand **Visibility, project features, permissions**.
1. Change **Project visibility** to either **Private**, **Internal**, or **Public**.
1. Select **Save changes**.

## Change group visibility

Prerequisite:

- You must have the Owner role for a group.
- Subgroups and projects must already have visibility settings that are at least as
  restrictive as the new setting for the group.

1. On the top bar, select **Menu > Groups** and find your project.
1. On the left sidebar, select **Settings > General**.
1. Expand **Naming, visibility**.
1. Under **Visibility level** select either **Private**, **Internal**, or **Public**.
1. Select **Save changes**.

## Restrict use of public or internal projects **(FREE SELF)**

You can restrict the use of visibility levels for users when they create a project or a snippet.
This is useful to prevent users from publicly exposing their repositories by accident. The
restricted visibility settings do not apply to administrators.

For details, see [Restricted visibility levels](admin_area/settings/visibility_and_access_controls.md#restrict-visibility-levels).

<!-- ## Troubleshooting

Include any troubleshooting steps that you can foresee. If you know beforehand what issues
one might have when setting this up, or when something is changed, or on upgrading, it's
important to describe those, too. Think of things that may go wrong and include them here.
This is important to minimize requests for support, and to avoid doc comments with
questions that you know someone might ask.

Each scenario can be a third-level heading, e.g. `### Getting error message X`.
If you have none to add when creating a doc, leave this section in place
but commented out to help encourage others to add to it in the future. -->
