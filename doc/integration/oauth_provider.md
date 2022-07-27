---
stage: Manage
group: Authentication and Authorization
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Configure GitLab as an OAuth 2.0 authentication identity provider

This document describes how you can use GitLab as an OAuth 2.0 authentication identity provider.

- OAuth 2 applications can be created and managed using the GitLab UI (described below)
  or managed using the [Applications API](../api/applications.md).
- After an application is created, external services can manage access tokens using the
  [OAuth 2 API](../api/oauth2.md).
- To allow users to sign in to GitLab using third-party OAuth 2 providers, see
  [OmniAuth documentation](omniauth.md).

## Introduction to OAuth

[OAuth 2](https://oauth.net/2/) provides to client applications a 'secure delegated
access' to server resources on behalf of a resource owner. OAuth 2 allows
authorization servers to issue access tokens to third-party clients with the approval
of the resource owner or the end-user.

OAuth 2 can be used:

- To allow users to sign in to your application with their GitLab.com account.
- To set up GitLab.com for authentication to your GitLab instance. See
  [GitLab OmniAuth](gitlab.md).

The 'GitLab Importer' feature also uses OAuth 2 to give access
to repositories without sharing user credentials to your GitLab.com account.

GitLab supports several ways of adding a new OAuth 2 application to an instance:

- [User owned applications](#user-owned-applications)
- [Group owned applications](#group-owned-applications)
- [Instance-wide applications](#instance-wide-applications)

The only difference between these methods is the [permission](../user/permissions.md)
levels. The default callback URL is `http://your-gitlab.example.com/users/auth/gitlab/callback`.

## User owned applications

To add a new application for your user:

1. In the top-right corner, select your avatar.
1. Select **Edit profile**.
1. On the left sidebar, select **Applications**.
1. Enter a **Name**, **Redirect URI** and OAuth 2 scopes as defined in [Authorized Applications](#authorized-applications).
   The **Redirect URI** is the URL where users are sent after they authorize with GitLab.
1. Select **Save application**. GitLab provides:

   - The OAuth 2 Client ID in the **Application ID** field.
   - The OAuth 2 Client Secret, accessible:
     - In the **Secret** field in GitLab 14.1 and earlier.
     - Using the **Copy** button on the **Secret** field
       [in GitLab 14.2 and later](https://gitlab.com/gitlab-org/gitlab/-/issues/332844).

## Group owned applications

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/16227) in GitLab 13.11.

To add a new application for a group:

1. Navigate to the desired group.
1. On the left sidebar, select **Settings > Applications**.
1. Enter a **Name**, **Redirect URI** and OAuth 2 scopes as defined in [Authorized Applications](#authorized-applications).
   The **Redirect URI** is the URL where users are sent after they authorize with GitLab.
1. Select **Save application**. GitLab provides:

   - The OAuth 2 Client ID in the **Application ID** field.
   - The OAuth 2 Client Secret, accessible:
     - In the **Secret** field in GitLab 14.1 and earlier.
     - Using the **Copy** button on the **Secret** field
       [in GitLab 14.2 and later](https://gitlab.com/gitlab-org/gitlab/-/issues/332844).

## Instance-wide applications

To create an application for your GitLab instance:

1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Applications**.
1. Select **New application**.

When creating application in the **Admin Area** , you can mark it as _trusted_.
The user authorization step is automatically skipped for this application.

## Access token expiration

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/21745) in GitLab 14.3, with the ability to opt out.
> - Ability to opt-out of expiring access token [removed](https://gitlab.com/gitlab-org/gitlab/-/issues/340848) in GitLab 15.0.

WARNING:
The ability to opt-out of expiring access tokens was [deprecated](https://gitlab.com/gitlab-org/gitlab/-/issues/340848)
in GitLab 14.3 and [removed](https://gitlab.com/gitlab-org/gitlab/-/issues/340848) in 15.0. All
existing integrations must be updated to support access token refresh.

Access tokens expire after two hours. Integrations that use access tokens must generate new ones at least every
two hours.

When applications are deleted, all grants and tokens associated with the application are also deleted.

## Authorized applications

Every application you authorize with your GitLab credentials is shown
in the **Authorized applications** section under **Settings > Applications**.

The GitLab OAuth 2 applications support scopes, which allow various actions that any given
application can perform. Available scopes are depicted in the following table.

| Scope              | Description |
| ------------------ | ----------- |
| `api`              | Grants complete read/write access to the API, including all groups and projects, the container registry, and the package registry. |
| `read_user`        | Grants read-only access to the authenticated user's profile through the /user API endpoint, which includes username, public email, and full name. Also grants access to read-only API endpoints under /users. |
| `read_api`         |  Grants read access to the API, including all groups and projects, the container registry, and the package registry. |
| `read_repository`  |  Grants read-only access to repositories on private projects using Git-over-HTTP or the Repository Files API. |
| `write_repository` | Grants read-write access to repositories on private projects using Git-over-HTTP (not using the API). |
| `read_registry`    |  Grants read-only access to container registry images on private projects. |
| `write_registry`   | Grants read-only access to container registry images on private projects. |
| `sudo`             | Grants permission to perform API actions as any user in the system, when authenticated as an administrator user. |
| `openid`           | Grants permission to authenticate with GitLab using [OpenID Connect](openid_connect_provider.md). Also gives read-only access to the user's profile and group memberships. |
| `profile`          |  Grants read-only access to the user's profile data using [OpenID Connect](openid_connect_provider.md). |
| `email`            |  Grants read-only access to the user's primary email address using [OpenID Connect](openid_connect_provider.md). |

At any time you can revoke any access by clicking **Revoke**.
